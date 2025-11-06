class AllowNullUsernameInUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :username, true
  end
end
