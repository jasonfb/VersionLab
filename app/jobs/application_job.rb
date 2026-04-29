class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  rescue_from(StandardError) do |exception|
    ExceptionNotifier.notify_exception(
      exception,
      data: { job: self.class.name, job_id: job_id, arguments: arguments }
    )
    raise exception
  end
end
