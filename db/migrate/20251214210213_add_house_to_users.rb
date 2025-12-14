class AddHouseToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :house, :boolean, default: false, null: false
    add_index :users, :house, unique: true, where: "house = true"
  end
end
