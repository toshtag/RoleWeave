# Pin npm packages by running ./bin/importmap

# 配るのは自前の application と Turbo だけとする（ADR 0068）。
# Stimulus の pin と app/javascript/controllers の走査は、
# controller を 1 つも持たないまま残っていた。

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
