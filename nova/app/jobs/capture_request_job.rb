class CaptureRequestJob < ApplicationJob
  queue_as :default

  def perform(message)
    # Do something later
    Rails.logger.info(message)
  end
end
