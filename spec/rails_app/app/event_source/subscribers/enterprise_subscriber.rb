# frozen_string_literal: true

module Subscribers
  # Subscriber will receive Enterprise requests like date change
  class EnterpriseSubscriber
    include ::EventSource::Subscriber[amqp: "enroll.enterprise.events"]

    subscribe(:on_date_advanced) do |delivery_info, metadata, response|
      logger.info "-" * 100 unless Rails.env.test?
      logger.info "EnterpriseSubscriber#on_date_advanced, response: #{response}"

      ack(delivery_info.delivery_tag)
    rescue StandardError, SystemStackError => e
      ack(delivery_info.delivery_tag)
    end

    subscribe(
      :on_enroll_enterprise_events
    ) do |delivery_info, _metadata, response|
      logger.info "-" * 100 unless Rails.env.test?
      logger.info "EnterpriseSubscriber#on_enroll_enterprise_events, response: #{response}"
  
      ack(delivery_info.delivery_tag)
    rescue StandardError, SystemStackError => e
      ack(delivery_info.delivery_tag)
    end
  end
end
