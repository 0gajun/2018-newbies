class AddUniqueToUserIdIntoCharges < ActiveRecord::Migration[5.2]
  def change
    add_index :charges, :user_id, :unique => true, :name => 'unique_for_duplicate_charge'
  end
end
