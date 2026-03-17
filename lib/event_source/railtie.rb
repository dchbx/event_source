# frozen_string_literal: true

require 'logger'

module EventSource
  # :nodoc:
  module Railtie
    Rails::Application::Finisher.initializer "event_source.boot", after: :finisher_hook do
      logger = Logger.new($stdout)
      logger.progname = 'EventSource graceful shutdown'
      timeouts = EventSource.config.shutdown_timeouts || {}
      amqp_timeout = timeouts[:amqp_drain] || 5

      # Perform shutdown work outside of trap/at_exit context to avoid
      # ThreadError from mutex operations within Bunny (AMQP client).
      shutdown = lambda do |reason|
        Thread.new do
          begin
            logger.info "#{reason}, starting graceful shutdown"
            logger.info "AMQP inflight handlers at shutdown start: #{EventSource.inflight_messages_count}"
            cm = EventSource::ConnectionManager.instance

            # Stop consuming and allow in-flight handlers to drain briefly
            cm.cancel_consumers_for(:amqp, timeout: amqp_timeout)
            cm.drop_connections_for(:amqp)
          rescue => e
            logger.error "graceful shutdown error: #{e.class}: #{e.message}"
          end
        end.join
      end

      if EventSource.config.auto_shutdown
        at_exit { shutdown.call('at_exit received') }

        %w[TERM INT].each do |sig|
          Signal.trap(sig) { shutdown.call("signal=#{sig} received") }
        end
      end
      EventSource.initialize!
    end
  end
end
