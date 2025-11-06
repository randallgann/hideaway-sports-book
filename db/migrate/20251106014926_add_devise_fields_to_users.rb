class AddDeviseFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Add Devise authentication fields
    add_column :users, :encrypted_password, :string, null: false, default: ""

    # Recoverable
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # Rememberable
    add_column :users, :remember_created_at, :datetime

    # OmniAuth
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string

    # Update email to match Devise requirements (not null, default empty string)
    change_column_default :users, :email, ""
    change_column_null :users, :email, false

    # Add Devise indexes
    add_index :users, :reset_password_token, unique: true
    add_index :users, [:provider, :uid], unique: true
  end
end
