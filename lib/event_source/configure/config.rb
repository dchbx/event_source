# frozen_string_literal: true

require 'deep_merge/rails_compat'

module EventSource
  module Configure
    # This class contains all the configuration for a running queue bus application.
    class Config
      include EventSource::Logging

      def initialize
        @log_level = :warn
      end

      # TODO: add default for pub_sub_root
      attr_writer :pub_sub_root, :protocols, :server_configurations
      attr_accessor :app_name, :log_level

      def load_protocols
        @protocols.each do |protocol|
          require "event_source/protocols/#{protocol}_protocol"
        end
      end

      def server_key=(value)
        @server_key = value&.to_sym
      end

      attr_writer :async_api_schemas

      def servers
        @server_configurations ||= Servers.new
        yield(@server_configurations)
      end

      def create_connections
        return unless @server_configurations
        validate_connections
        connection_manager = EventSource::ConnectionManager.instance

        @server_configurations.configurations.each do |server_conf|
          settings = server_conf.to_h
          settings[:url] = format_urls_for_server_config(settings)
          connection_manager.add_connection(settings)
        end
      end

      def validate_connections
        validation_result =
          ::EventSource::Configure::Operations::ValidateServerConfigurations.new
            .call(@server_configurations)
        return if validation_result.success?
        validation_result.failure.each do |result|
          formatted_trace =
            result.first.call_location.first(3).map do |e_line|
              "    #{e_line}"
            end.join("\n")
          logger.error "Server Configuration Invalid\n  Errors: #{result.last.to_h}\n  At:\n#{formatted_trace}"
        end
        first_failure = validation_result.failure.first
        exception =
          Error::ServerConfigurationInvalid.new(
            "Server configuration invalid: #{first_failure.last.to_h}"
          )
        exception.set_backtrace first_failure.first.call_location
        raise exception
      end

      def format_urls_for_server_config(settings)
        return settings[:url] if settings[:url]
        url = ''
        case settings[:protocol]
        when :amqp, :amqps, 'amqp', 'amqps'
          vhost = settings[:vhost].blank? ? '/' : settings[:vhost]
          port_part =
            settings[:port].present? ? [':', settings[:port]].join : ''
          url = [settings[:host], port_part, vhost].join
        else
          port_part =
            settings[:port].present? ? [':', settings[:port]].join : ''
          url = [settings[:host], port_part].join
        end
        url = "#{settings[:protocol]}://" + url unless url.match(%r{^\w+://})
        url
      end

      def load_async_api_resources
        return unless @async_api_schemas

        @async_api_schemas.each do |resource|
          resource.channels.each do |async_api_channel_item|
            if async_api_channel_item.publish.present?
              process_resource_for(
                resource.servers,
                async_api_channel_item.id.to_sym,
                async_api_channel_item
              )
            end
          end
        end

        @async_api_schemas.each do |resource|
          resource.channels.each do |async_api_channel_item|
            next if async_api_channel_item.publish.present?
            next unless async_api_channel_item.subscribe.present?
            process_resource_for(
              resource.servers,
              async_api_channel_item.id.to_sym,
              async_api_channel_item
            )
          end
        end
      end

      def connection_manager
        return @connection_manager if defined?(@connection_manager)
        @connection_manager = EventSource::ConnectionManager.instance
      end

      def process_resource_for(
        servers,
        channel_item_key,
        async_api_channel_item
      )
        return unless servers

        matching_server = servers.detect { |s| s.id.to_s == @server_key.to_s }
        unless matching_server
          logger.error do
            "Unable to find server configuration for #{@server_key}"
          end
          raise EventSource::Error::ServerConfigurationNotFound,
                "unable to find server configuration for #{@server_key}"
        end

        connection = connection_manager.fetch_connection(matching_server)

        unless connection
          logger.error do
            "Unable to find connection for #{@server_key} with servers: #{servers}, connections: #{connection_manager.connections.keys}"
          end
          raise EventSource::Error::ConnectionNotFound,
                "unable to find connection for #{@server_key} with #{servers}"
        end

        unless connection.active?
          logger.info { "Connecting #{connection.connection_uri}" }
        end
        connection.start
        logger.info { "Connected to #{connection.connection_uri}" }

        connection.add_channel(channel_item_key, async_api_channel_item)
      end

      def load_components
        return unless @pub_sub_root
        %w[publishers subscribers].each do |folder|
          Dir["#{@pub_sub_root}/#{folder}/**/*.rb"].sort.each do |file|
            require file
          end
        end
      end

      def delimiter(protocol)
        case protocol
        when :http
          '/'
        else
          '.'
        end
      end
    end
  end
end
