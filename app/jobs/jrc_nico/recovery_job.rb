class JrcNico::RecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    JrcNico::Run.where(status: 'queued').where('created_at < ?', 2.minutes.ago).find_each do |run|
      JrcNico::AnalyzeJob.perform_later(run.id)
    end
    JrcNico::Run.where(status: 'running').where('started_at < ?', 3.minutes.ago).find_each do |run|
      run.with_lock do
        next unless run.status == 'running' && run.started_at < 3.minutes.ago

        # The provider may have billed an abandoned request. Keep its reservation and never replay it.
        run.update!(status: 'failed', error_code: 'interrupted_unknown_outcome', finished_at: Time.current)
      end
    end
  end
end
