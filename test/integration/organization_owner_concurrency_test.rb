require "test_helper"

# 組織の管理者を 0 人にできないことを、並行した操作に対して検証する。
#
# 検証対象は、**owner を減らす経路が互いを知らずに進まないこと**である。
# 経路は 2 つある。役割の変更と、アカウントの削除である。
# 片方だけを直すと、残った経路から同じ状態を作れる。
class OrganizationOwnerConcurrencyTest < ActiveSupport::TestCase
  # 別の接続から同じ行を見る必要がある。
  # テストのトランザクションの中で作ると、他の接続からは見えない。
  self.use_transactional_tests = false

  PASSWORD = "correct horse battery".freeze

  setup do
    @first = confirmed_user("owner1@example.com")
    @second = confirmed_user("owner2@example.com")
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @first)
    @organization.memberships.create!(user: @second, role: "owner", changed_by: @first)
  end

  teardown do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.truncate_tables(*(connection.tables - %w[schema_migrations ar_internal_metadata]))
    end
  end

  test "owner が 2 人のときに互いを同時に降格しても、owner が残る" do
    results = in_parallel([ @first, @second ]) do |actor|
      target = @organization.memberships.where.not(user_id: actor.id).sole

      demote(target.id, actor.id)
    end

    assert_equal 1, results.count(true)
    assert_equal 1, owner_count
  end

  test "owner が 2 人のときに同時にアカウントを削除しても、owner が残る" do
    results = in_parallel([ @first, @second ]) { |actor| delete_account(actor.id) }

    assert_equal 1, results.count(true)
    assert_equal 1, owner_count
  end

  test "降格とアカウントの削除が同時に走っても、owner が残る" do
    target = @organization.memberships.find_by!(user: @second)

    results = in_parallel([ :demote, :delete ]) do |operation|
      operation == :demote ? demote(target.id, @first.id) : delete_account(@first.id)
    end

    assert_equal 1, results.count(true)
    assert_equal 1, owner_count
  end

  test "owner が 3 人なら、2 人を同時に降格できる" do
    third = confirmed_user("owner3@example.com")
    @organization.memberships.create!(user: third, role: "owner", changed_by: @first)

    results = in_parallel([ @second, third ]) do |target|
      demote(@organization.memberships.find_by!(user: target).id, @first.id)
    end

    assert_equal 2, results.count(true)
    assert_equal 1, owner_count
  end

  test "唯一の owner でなければ、アカウントを削除できる" do
    assert delete_account(@second.id)
    assert_equal 1, owner_count
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def owner_count
      @organization.memberships.where(role: "owner").count
    end

    # 役割を owner から member へ変える。
    # 行は thread ごとに読み直す。同じ instance を共有すると状態を奪い合う。
    def demote(membership_id, actor_id)
      membership = Membership.find(membership_id)
      membership.changed_by = User.find(actor_id)

      membership.update_within_owner_invariant(role: "member")
    end

    def delete_account(user_id)
      AccountDeletion.new(User.find(user_id)).delete!
    rescue ActiveRecord::RecordNotDestroyed
      false
    end

    def in_parallel(items, &operation)
      barrier = Concurrent::CyclicBarrier.new(items.size)

      items.map do |item|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            # 数える前に足並みをそろえる。ここをそろえないと、
            # たまたま直列に走って owner が残ることがある。
            barrier.wait
            operation.call(item)
          end
        end
      end.map(&:value)
    end
end
