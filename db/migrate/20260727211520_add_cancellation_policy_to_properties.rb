class AddCancellationPolicyToProperties < ActiveRecord::Migration[8.1]
  def change
    # 0 = strict (no refund after the free-cancellation cutoff), 1 = partial (50%).
    add_column :properties, :cancellation_policy, :integer, default: 0, null: false
  end
end
