# frozen_string_literal: true

require 'deep_merge/rails_compat'

module EventSource
  module Configure
    SoapConfiguration = Struct.new(:user_name, :password, :password_encoding, :use_timestamp, :timestamp_ttl, :call_location) do
      def password_digest?
        password_encoding == :digest
      end

      def security_timestamp?
        !!use_timestamp
      end

      def to_h
        attribute_hash = super()
        attribute_hash.compact
      end
    end

    ClientCertificateConfiguration = Struct.new(:client_certificate, :client_key, :client_key_password, :call_location) do
      def to_h
        attribute_hash = super()
        attribute_hash.compact
      end
    end

    AmqpConfiguration = Struct.new(:protocol, :ref, :host, :vhost, :port, :url, :user_name, :password, :call_location, :default_content_type)

    HttpConfiguration = Struct.new(:protocol, :ref, :host, :port, :url, :user_name, :password, :soap_settings, :client_certificate_settings,
                                   :call_location, :default_content_type) do
      def soap
        s_settings = SoapConfiguration.new
        s_settings.call_location = caller(1)
        yield(s_settings)
        self.soap_settings = s_settings
      end

      def client_certificate
        cc_settings = ClientCertificateConfiguration.new
        cc_settings.call_location = caller(1)
        yield(cc_settings)
        self.client_certificate_settings = cc_settings
      end

      def soap?
        soap_settings.present?
      end

      def client_cert?
        client_certificate_settings.present?
      end

      def to_h
        attribute_hash = super()
        main_hash = attribute_hash.compact
        main_hash.delete(:soap_settings)
        main_hash.delete(:client_certificate_settings)
        main_hash = main_hash.merge({ soap: soap_settings.to_h }) if soap?
        main_hash = main_hash.merge({ client_certificate: client_certificate_settings.to_h }) if client_certificate_settings
        main_hash
      end
    end

    # Represents a server configuration.
    class Servers
      attr_reader :default_content_type, :configurations

      def initialize
        @configurations = []
      end

      def http
        http_conf = HttpConfiguration.new(:http)
        http_conf.call_location = caller(1)
        yield(http_conf)
        @configurations.push(http_conf)
      end

      def amqp
        amqp_conf = AmqpConfiguration.new(:amqp)
        amqp_conf.call_location = caller(1)
        yield(amqp_conf)
        @configurations.push(amqp_conf)
      end
    end
  end
end