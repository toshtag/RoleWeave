Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 検索エンジン向けの配信。ロケールを持たない URL とする。
  # 静的ファイルにすると、自己ホストの利用者ごとにホスト名の書き換えが要る。
  # format: false により、拡張子を含む path をそのまま扱う。
  # 既定の解釈では .xml が format として切り出され、URL helper が拡張子を失う。
  get "sitemap.xml" => "public/sitemaps#show", as: :sitemap, format: false
  get "robots.txt" => "public/robots#show", as: :robots, format: false

  # 利用者向けページはロケールを明示した URL へ置く。
  # 詳細は docs/decisions/0001-locale-prefixed-routes.md を参照する。
  #
  # / へ同じ内容を描画せず既定ロケールへ遷移させ、日本語の入口を 1 つの URL に保つ。
  root to: redirect("/#{I18n.default_locale}", status: :found)

  # 対応ロケールの制約は I18n の設定から導出する。
  # route 側へ言語を書き写すと、対応言語の増減で設定と制約が食い違う。
  scope ":locale", locale: Regexp.union(I18n.available_locales.map(&:to_s)) do
    root "home#show", as: :localized_root

    # 求職者が見る求人。組織側の管理画面とは経路を分ける。
    # 詳細は docs/decisions/0020-public-job-posting-urls.md を参照する。
    resources :jobs, only: %i[index show], controller: "public/job_postings", as: :public_job_postings do
      # 応募。求人の下へ置く。応募元は経路から受け取らず、常に本人のプロフィールとする。
      # 詳細は docs/decisions/0034-job-application.md を参照する。
      resource :application, only: %i[new create], controller: "job_applications"
    end

    # ログイン状態は 1 つしか持たないため、単数形の resource とする。
    # ログアウトは DELETE で行う。GET で状態を変えると、
    # 先読みやリンクの巡回だけでログアウトが起こる。
    resource :session, only: %i[new create destroy]

    # アカウントは自分の 1 件だけを扱うため、単数形の resource とする。
    resource :registration, only: %i[new create]

    # 所属する組織。作成と一覧だけを持つ。
    resources :organizations, only: %i[index new create] do
      resources :invitations, only: %i[new create]
      resources :memberships, only: %i[index update]
      # 求職者のプロフィールの詳細。一覧は持たない。
      # 一覧があること自体が、公開範囲を「探されてよい」という意味へ変えてしまう。
      # 受信を許可した候補者の検索とタレントプール。
      # 詳細は docs/decisions/0055-candidate-search.md を参照する。
      resources :candidate_searches, only: :index, module: :organizations
      # スカウトとテンプレート。
      # 詳細は docs/decisions/0056-scouting.md を参照する。
      # 外部への配信先。管理者だけが扱う。
      # 詳細は docs/decisions/0057-webhooks.md を参照する。
      resources :webhooks, only: %i[index create destroy], module: :organizations
      resources :scouts, only: %i[index new create], module: :organizations
      resources :scout_templates, only: %i[index create destroy], module: :organizations
      resources :talent_pools, only: %i[index show create destroy], module: :organizations do
        resources :members, only: %i[create destroy], controller: "talent_pool_members"
      end
      resources :candidate_profiles, only: :show, module: :organizations do
        # 添付は、公開範囲と添付の設定の両方が開いているときだけ取れる。
        get "documents/:kind" => "candidate_profile_documents#show", as: :document
      end
      resources :job_postings, only: %i[index new create edit update] do
        # 公開されたときと同じ見え方の確認。公開側の経路とは別に置く。
        get :preview, on: :member

        # 公開状態を変える経路は、編集とは別に置く。
        # 同じ経路にすると、編集の権限がそのまま公開の権限になる。
        patch :submit, to: "job_posting_reviews#submit"
        patch :approve, to: "job_posting_reviews#approve"
        patch :reject, to: "job_posting_reviews#reject"
        patch :suspend, to: "job_posting_reviews#suspend"

        # 届いた応募。求人の下へ置く。
        # 詳細は docs/decisions/0036-organization-application-access.md を参照する。
        resources :applications, only: %i[index show], module: :organizations,
                                 controller: "job_applications" do
          # 選考ステージを進める経路。見る経路とは分けて置く。
          # 詳細は docs/decisions/0038-selection-stage.md を参照する。
          patch "stage/:stage", to: "job_application_stages#update", as: :stage
          # 評価とコメント。読み書きできるのは所属者だけとする。
          # 詳細は docs/decisions/0039-application-review-and-assignment.md を参照する。
          resources :reviews, only: :create, controller: "application_reviews"
          resource :assignment, only: :update, controller: "job_application_assignments"
          # 面接の予定と結論の期限。所属者だけが扱う。
          # 詳細は docs/decisions/0040-interview-schedule-and-deadline.md を参照する。
          resources :interviews, only: %i[create destroy], controller: "interview_schedules"
          resource :deadline, only: :update, controller: "job_application_deadlines"
        end
      end
    end

    # 運営者専用の経路。通常の組織の画面とは分けて置く。
    # 混ぜると、組織の所属に基づく制限と運営者の権限が同じ経路の中で絡み合う。
    namespace :operator do
      resources :organizations, only: %i[index show] do
        resources :memberships, only: :update
      end

      # 配信に失敗した通知の一覧と再送。
      # 詳細は docs/decisions/0043-notification-delivery-failures.md を参照する。
      resources :notification_deliveries, only: %i[index update]

      # 個人情報を読んだ操作の一覧。
      # 詳細は docs/decisions/0047-access-audit-log.md を参照する。
      resources :access_events, only: :index
    end

    # 招待の受諾。token は URL のパスへ置く。
    # query string へ置くと、Referer やアクセスログへ残りやすい。
    get "invitation/:token" => "invitations#show", as: :invitation

    # 応募に使うプロフィール。対象は常に本人のものとし、ID を受け取らない。
    # 詳細は docs/decisions/0026-candidate-profile.md を参照する。
    resource :profile, only: %i[show new create edit update destroy], controller: "candidate_profiles" do
      # 職歴はプロフィールへ従属する。プロフィールの外側へ置くと、
      # 「誰の職歴か」を経路ごとに確かめることになる。
      # 詳細は docs/decisions/0027-work-experience.md を参照する。
      resources :work_experiences, only: %i[index new create edit update destroy]
      resources :educations, only: %i[index new create edit update destroy]
      resources :skills, only: %i[index new create edit update destroy]
      resource :desired_condition, only: %i[edit update]
      # 公開範囲は編集の画面と分けて置く。
      # 同じ画面にすると、書き換えのついでに範囲が変わりうる。
      resource :visibility, only: %i[edit update], controller: "profile_visibilities"

      # 履歴書・職務経歴書。種類はパスへ置き、決まった 2 つだけを受け取る。
      # 詳細は docs/decisions/0031-profile-documents.md を参照する。
      resource :documents, only: %i[edit update], controller: "profile_documents"

      # 自分の応募。応募そのものの経路（求人の下）とは分けて置く。
      # 詳細は docs/decisions/0035-application-withdrawal.md を参照する。
      resources :applications, only: %i[index show destroy], controller: "candidate_job_applications"

      # 保存した求人と検索条件。
      # 詳細は docs/decisions/0054-saved-searches.md を参照する。
      resources :saved_jobs, only: %i[index create destroy], controller: "saved_job_postings"
      resources :saved_searches, only: %i[index create update destroy]

      # 受け取ったスカウトと、組織ごとの配信停止。
      resources :scouts, only: :index, controller: "candidate_scouts"
      resources :scout_blocks, only: %i[create destroy]
    end

    # 添付そのものの経路。種類をパスへ置く。
    get "profile/documents/:kind" => "profile_documents#show", as: :profile_document
    delete "profile/documents/:kind" => "profile_documents#destroy"

    # 自分への通知と、メールの受け取りの設定。
    # 詳細は docs/decisions/0042-notifications.md を参照する。
    resources :notifications, only: :index
    resource :notification_settings, only: %i[edit update]

    # 応募に紐づく会話。応募者と組織の所属者が同じ経路を使う。
    # 詳細は docs/decisions/0041-application-conversation.md を参照する。
    resources :applications, only: [] do
      resource :conversation, only: %i[show create]
    end

    # 自分のデータの持ち出し。対象は常にログインしている本人とする。
    # 詳細は docs/decisions/0032-personal-data-export.md を参照する。
    resource :export, only: :show, controller: "profile_exports"

    # 自分のアカウント情報。ログインとメールアドレスの確認を要する。
    resource :account, only: :show

    # アカウントの削除。確認の画面を挟み、パスワードの再入力を求める。
    # 詳細は docs/decisions/0033-account-deletion.md を参照する。
    resource :account_deletion, only: %i[show destroy]

    # パスワード再設定。依頼は token を持たず、再設定は token を持つ。
    # token は URL のパスへ置く。query string へ置くと、Referer やアクセスログへ残りやすい。
    resource :password_reset, only: %i[new create]
    get "password_reset/edit/:token" => "password_resets#edit", as: :edit_password_reset
    patch "password_reset/:token" => "password_resets#update", as: :update_password_reset

    # メールアドレスの確認。token は URL のパスへ置く。
    # query string へ置くと、Referer やアクセスログへ残りやすい。
    get "confirmation/:token" => "confirmations#show", as: :confirmation
  end
end
