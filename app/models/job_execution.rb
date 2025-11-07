class JobExecution < ApplicationRecord
  validates :job_name, presence: true
  validates :executed_at, presence: true

  # Record a job execution
  def self.record(job_name, status: 'success', executed_at: Time.current)
    create!(
      job_name: job_name,
      executed_at: executed_at,
      status: status
    )
  end

  # Get the last execution time for a specific job
  def self.last_execution_time(job_name)
    where(job_name: job_name).maximum(:executed_at)
  end
end
