# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'uri'

require_relative 'http/error'
require_relative 'http/types'
require_relative 'http/soap'
require_relative 'http/faraday_request_proxy'
require_relative 'http/faraday_queue_proxy'
require_relative 'http/faraday_channel_proxy'
require_relative 'http/faraday_connection_proxy'

# Fix this to be explicit
Gem.find_files('event_source/protocols/http/contracts/**/*.rb').sort.each { |f| require(f) }

module EventSource
  module Protocols
    # Namespace for classes and modules that use AsyncAPI to handle message
    # exchange using HTTP protcol
    # @since 0.5.0
    module Http
    end
  end
end
