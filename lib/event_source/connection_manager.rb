# frozen_string_literal: true

require 'singleton'
module EventSource
  # A DSL for registering and managing {EventSource::Connection}s between
  #   network resources
  class ConnectionManager
    include Singleton
    include EventSource::Logging

    # @attr_reader [Hash] connections The connection registry
    attr_reader :connections

    def initialize
      @connections = Hash.new
    end

    # Add a list of connections for the given set of server configurations
    #   to the connection registry
    # @param [Array] async_api_servers Async Api Server objects in Hash format
    def add_connections(async_api_servers, _servers)
      async_api_servers.each do |async_api_server|
        add_connection(async_api_server)
      end
    end

    # Add a network resource to the connection registry
    # This resource is a connection configuration object.
    def add_connection(async_api_server)
      client_klass = protocol_klass_for(async_api_server[:protocol])
      async_api_server[:ref] ||=
        client_klass.connection_uri_for(async_api_server)
      connection_uri = async_api_server[:ref]

      return connections[connection_uri] if connections.key? connection_uri
      client = client_klass.new(async_api_server)
      connections[connection_uri] = EventSource::Connection.new(client)
    end

    # Find a registered {EventSource::Connection} instance that matches
    #   an {EventSource::AsyncApi::Server} configuration
    # @return [EventSource::Connection] Connection
    def fetch_connection(async_api_server)
      # raise connections.keys.inspect
      client_klass = protocol_klass_for(async_api_server.protocol)
      connection_uri = client_klass.connection_uri_for(async_api_server)
      connections[connection_uri]
    end

    # Find all registered connections for the given protocol
    # @param [Symbol] protocol the protocol name, for
    #   example: `:http` or `:amqp`
    # @return [Array<EventSource::Connection>] connections filtered
    #   list of registered connections
    def connections_for(protocol)
      connections.reduce(
        []
      ) do |protocol_connections, (_connection_uri, connection_instance)|
        if connection_instance.protocol == protocol
          protocol_connections << connection_instance
        end
        protocol_connections
      end
    end

    # Find a registered {EventSource::Connection} that matches the given
    #   protocol and channel
    # @param [Symbol] protocol the connection protocol type,
    #   e.g. `:http` or `:amqp`
    # @param [Symbol] channel_key the Channel identifier
    # @return [EventSource::Connection] Connection instance
    def connection_by_protocol_and_channel(protocol, channel_key)
      connections_for(protocol).detect do |connection|
        connection.channels.key?(channel_key.to_sym)
      end
    end

    # Find a registered {EventSource::Connection} that matches search criteria
    # @param [Hash] params search criteria
    # @option params [Symbol] :protocol the protocol name, e.g. `:http` or `:amqp`
    # @option params [String] :publish_operation_name Publish operation name
    # @option params [String] :subscribe_operation_name Subscribe operation name
    # @return [EventSource::Connection] Connection
    def find_connection(params)
      connections = connections_for(params[:protocol])

      if params[:publish_operation_name]
        connections.detect do |connection|
          connection.publish_operation_exists?(params[:publish_operation_name])
        end
      else
        connections.detect do |connection|
          connection.subscribe_operation_exists?(
            params[:subscribe_operation_name]
          )
        end
      end
    end

    # Find a registered {EventSource::PublishOperation} that matches search
    #   criteria
    # @param [Hash] params search criteria
    # @option params [String] :publish_operation_name PublishOperation name
    # @return [EventSource::PublishOperation] publish_operation PublishOperation instance
    def find_publish_operation(params)
      logger.debug "find publish operation with #{params}"
      connection = find_connection(params)

      if connection
        logger.debug "found connection for #{params}"
        connection.find_publish_operation_by_name(
          params[:publish_operation_name]
        )
      else
        logger.error "Unable find connection for publish operation: #{params}"
        connection
      end
    end

    # Find a registered {EventSource::SubscribeOperation} that matches search
    #   criteria
    # @param [Hash] params search criteria
    # @option params [String] :publish_operation_name SubscribeOperation name
    # @return [EventSource::SubscribeOperation] subscribe_operation SubscribeOperation instance
    def find_subscribe_operation(params)
      logger.debug "find subscribe operation with #{params}"
      connection = find_connection(params)

      if connection
        logger.debug "found connection for #{params}"
        connection.find_subscribe_operation_by_name(
          params[:subscribe_operation_name]
        )
      else
        logger.error "Unable find connection for subscribe operation: #{params}"
        connection
      end
    end

    # Drop all registered connections for the given protocol
    # @param [Symbol] protocol the protocol name, for
    #   example: `:http` or `:amqp`
    # @return [Array<EventSource::Connection>] registered connections
    def drop_connections_for(protocol)
      connections.each do |connection_uri, connection_instance|
        if connection_instance.protocol == protocol
          drop_connection(connection_uri)
        end
      end
    end

    # Remove a network resource from the connection registry
    # @param connection_uri [String] the unique key for the connection to
    #   remove
    # @return [Array] connections the list of registered connections
    def drop_connection(connection_uri)
      connection = connections[connection_uri]
      connection.disconnect if connection.active?
      connections.delete connection_uri
      connections
    end

    def cancel_consumers_for(protocol, timeout: 5)
      protocol_value = protocol.to_s.upcase
      logger.info "Cancelling #{protocol_value} consumers prior to shutdown"
      connections = connections_for(protocol)
      any_consumers = connections.any? { |connection| connection_has_consumers?(connection) }
      logger.info "#{protocol_value} inflight handlers (before_cancel): #{EventSource.inflight_messages_count}, any_consumers=#{any_consumers}"

      connections.each do |connection|
        connection.channels.each_value do |channel|
          channel.cancel_consumers
        end
      end

      wait_for_connections_to_drain(connections, timeout)

      logger.info "#{protocol_value} consumer cancellation complete"
      logger.info "#{protocol_value} inflight handlers (end): #{EventSource.inflight_messages_count}"
    end

    private

    def wait_for_connections_to_drain(connections, timeout)
      return if connections.empty?

      protocol = connections.first.protocol.to_s.upcase
      start = Time.now

      loop do
        inflight = EventSource.inflight_messages_count
        any_consumers = connections.any? { |connection| connection_has_consumers?(connection) }

        logger.info "#{protocol} inflight handlers (drain): #{inflight}, any_consumers=#{any_consumers}"
        break if inflight.zero? && !any_consumers
        break if (Time.now - start) >= timeout
        sleep 0.1
      end
    end

    def connection_has_consumers?(connection)
      connection.channels.values.any? do |channel|
        begin
          channel.channel_proxy.subject.any_consumers?
        rescue StandardError
          false
        end
      end
    end

    # Find connection proxy class for given protocol
    # @param [Symbol] protocol the protocol name, `:http` or `:amqp`
    # @return [Class] Protocol Specific Connection Proxy Class
    def protocol_klass_for(protocol)
      case protocol.to_sym
      when :amqp, :amqps, 'amqp', 'amqps'
        EventSource::Protocols::Amqp::BunnyConnectionProxy
      when :http, :https, 'http', 'https'
        EventSource::Protocols::Http::FaradayConnectionProxy
      else
        raise EventSource::Protocols::Amqp::Error::UnknownConnectionProtocolError,
              "unknown protocol: #{protocol}"
      end

      # raise EventSource::AsyncApi::Error::UnknownConnectionProtocolError,
      #        "unknown protocol: #{protocol}"
    end
  end
end

# Servers.create returning a dry struct
# Servers.connect with server struct
#   - ConnectionManager.connect(server)

# servers:
#   production:
#     url: https://example.com
#     protocol: amqp
#     protocolVersion: "0.9.2"
#     description: RabbitMQ Production Server
#   test:
#     url: https://test.example.com
#     protocol: amqp
#     protocolVersion: "0.9.2"
#     description: RabbitMQ Test Server
