# frozen_string_literal: true

require 'forwardable'
require 'date'
require 'dry/types/type'
require 'dry/monads'
require 'dry/monads/do'
require 'dry/monads/result'
require 'dry/inflector'
require 'dry/validation'
require 'dry-struct'
require 'oj'
require 'active_support/all' # TODO: Remove ActiveSupport dependency
require 'deep_merge/rails_compat'

require 'event_source/version'
require 'event_source/ruby_versions'
require 'event_source/error'
require 'event_source/inflector'
require 'event_source/logging'
require 'event_source/uris/uri'
require 'event_source/types'
require 'event_source/content_type_resolver'
require 'event_source/async_api/types'
require 'event_source/async_api/async_api'
require 'event_source/railtie' if defined?(Rails)
require 'event_source/configure'
require 'event_source/connection'
require 'event_source/connection_manager'
require 'event_source/channel'
require 'event_source/queue'
require 'event_source/worker'
require 'event_source/publish_operation'
require 'event_source/subscribe_operation'
require 'event_source/message'
require 'event_source/command'
require 'event_source/publisher'
require 'event_source/event'
require 'event_source/subscriber'
require 'event_source/operations/codec64'
require 'event_source/operations/create_message'
require 'event_source/operations/fetch_session'
require 'event_source/operations/build_message_options'
require 'event_source/operations/build_message'

# Event source provides ability to compose, publish and subscribe to events
module EventSource
  # Noop Event class
  class Noop
    def to_s
      'no operation'
    end
  end
  class << self
    extend Forwardable

    def_delegators :config,
                   :pub_sub_root,
                   :app_name,
                   :load_protocols,
                   :create_connections,
                   :load_async_api_resources,
                   :load_components,
                   :delimiter,
                   :async_api_schemas=

    def configure
      yield(config)
    end

    def initialize!
      load_protocols
      create_connections
      load_async_api_resources
      load_components
    end

    def config
      @config ||= EventSource::Configure::Config.new
    end

    # Call this method on fork of a rails app you are working in.
    # It cleans up your connections and channels and avoids strange
    # behaviour.
    def reconnect_publishers!; end

    def build_async_api_resource(resource)
      EventSource::AsyncApi::Operations::AsyncApiConf::Create
        .new
        .call(resource)
        .success
    end
  end

  class EventSourceLogger
    include EventSource::Logging
  end
end
