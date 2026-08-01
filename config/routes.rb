Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 利用者向けページはロケールを明示した URL へ置く。
  # 詳細は docs/decisions/0001-locale-prefixed-routes.md を参照する。
  #
  # / へ同じ内容を描画せず既定ロケールへ遷移させ、日本語の入口を 1 つの URL に保つ。
  root to: redirect("/#{I18n.default_locale}", status: :found)

  # 対応ロケールの制約は I18n の設定から導出する。
  # route 側へ言語を書き写すと、対応言語の増減で設定と制約が食い違う。
  scope ":locale", locale: Regexp.union(I18n.available_locales.map(&:to_s)) do
    root "home#show", as: :localized_root

    # ログイン状態は 1 つしか持たないため、単数形の resource とする。
    # ログアウトは DELETE で行う。GET で状態を変えると、
    # 先読みやリンクの巡回だけでログアウトが起こる。
    resource :session, only: %i[new create destroy]

    # アカウントは自分の 1 件だけを扱うため、単数形の resource とする。
    resource :registration, only: %i[new create]

    # メールアドレスの確認。token は URL のパスへ置く。
    # query string へ置くと、Referer やアクセスログへ残りやすい。
    get "confirmation/:token" => "confirmations#show", as: :confirmation
  end
end
