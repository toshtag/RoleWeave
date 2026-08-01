class CreateAuthenticationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :authentication_events do |t|
      # アカウントへ結び付かない出来事がある。
      # 存在しないメールアドレスへの試行は、どのアカウントのものでもない。
      #
      # アカウントを削除しても記録は残す。誰の操作だったかは失われるが、
      # 「いつ何が起きたか」まで消すと、削除の前後の調査ができなくなる。
      t.references :user, null: true, foreign_key: { on_delete: :nullify }

      # 出来事の種類。取り得る値は AuthenticationEvent が持つ。
      t.string :kind, null: false

      # 入力されたメールアドレス。正規化して記録する。
      # 詳細は docs/decisions/0010-authentication-events.md を参照する。
      t.string :email_address, null: false

      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    # 調査は「このアカウントの直近」と「このアドレスへの直近」の 2 方向から始まる。
    add_index :authentication_events, [ :user_id, :created_at ]
    add_index :authentication_events, [ :email_address, :created_at ]
  end
end
