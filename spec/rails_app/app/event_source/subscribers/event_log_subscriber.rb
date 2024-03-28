# frozen_string_literal: true

module Subscribers
  # Subscriber will receive Audit Log events
  class EventLogSubscriber
    include EventSource::Logging
    include ::EventSource::Subscriber[amqp: "enroll.audit_log.events"]

    subscribe(
      :on_enroll_audit_log_events
    ) do |delivery_info, metadata, response|
      logger.info "-" * 100 unless Rails.env.test?

      subscriber_logger.info "EventLogEventsSubscriber#on_enroll_audit_log_events, response: #{response}"

      ack(delivery_info.delivery_tag)
    rescue StandardError, SystemStackError => e
      ack(delivery_info.delivery_tag)
    end

    private

    def subscriber_logger
      @subscriber_logger ||=
        Logger.new("#{Rails.root}/log/on_enroll_audit_log_events.log")
    end
  end
end
