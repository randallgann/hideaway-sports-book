class CreateJobExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :job_executions do |t|
      t.string :job_name, null: false
      t.datetime :executed_at, null: false
      t.string :status

      t.timestamps
    end

    add_index :job_executions, :job_name
    add_index :job_executions, [:job_name, :executed_at]
  end
end
