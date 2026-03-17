# frozen_string_literal: true

require 'bunny'
require 'uri'

require 'event_source/uris/amqp_uri'
require_relative 'amqp/error'
require_relative 'amqp/bunny_message_proxy'
require_relative 'amqp/bunny_exchange_proxy'
require_relative 'amqp/bunny_consumer_handler'
require_relative 'amqp/bunny_queue_proxy'
require_relative 'amqp/bunny_channel_proxy'
require_relative 'amqp/bunny_connection_proxy'
require_relative 'amqp/bunny_consumer_proxy'
require_relative 'amqp/contracts/contract'

Gem
  .find_files('event_source/protocols/amqp/contracts/**/*.rb', false)
  .sort
  .each { |f| require(f) }

module EventSource
  module Protocols
    # Namespace for classes and modules that use AsyncAPI to manage message
    # exchange using the AMQP protcol
    # @since 0.4.0
    module Amqp
    end
  end
end
