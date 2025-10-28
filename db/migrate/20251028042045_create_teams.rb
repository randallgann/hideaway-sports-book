class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :city
      t.string :abbreviation
      t.string :sport

      t.timestamps
    end
  end
end
