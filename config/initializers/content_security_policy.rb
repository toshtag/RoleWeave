# Content Security Policy。
#
# このアプリケーションは外部のスクリプトも外部の CSS も読み込まない。
# Importmap と Propshaft で自前の資産だけを配る。
# そのため、既定を self とする厳しい値から始められる。
# 方針は docs/decisions/0045-content-security-policy.md を正本とする。
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    # 静的エラー画面（ADR 0003）は style 要素を持つ。
    # これらは描画経路を通さずに読めることが要件であり、外部の CSS を使えない。
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self
    # 別のサイトの枠の中へ埋め込ませない。
    policy.frame_ancestors :none
  end

  # 報告だけの動作にはしない。
  # 報告だけでは、違反があっても実際には防いでいない。
  config.content_security_policy_report_only = false
end
