# frozen_string_literal: true

EventSource.configure do |config|
  config.protocols = %w[amqp http]
  config.pub_sub_root = Pathname.pwd.join('spec', 'rails_app', 'app', 'event_source')
  config.server_key = Rails.env.to_sym
  config.app_name = :enroll
  config.log_level = :warn

  config.servers do |server|
    # mitc
    # server.http do |http|
    #   http.environment = :production
    #   http.host = ENV['RABBITMQ_HOST']
    #   http.port =
    #   # http.user_name =
    # end

    # FDSH_HOST="dev.hub.cms.gov"
    # FDSH_PORT=5443
    # FDSH_URL="http://dev.hub.cms.gov:5443"
    # FDSH_USERNAME="my_id"
    # FDSH_PASSWORD="my_pwd"
    # FDSH_CERT_FILE="/path/to/cert.pem"
    # FDSH_KEY_FILE="/path/to/key.pem"
    # # fdsh
    # server.http do |http|
    #   http.environment = :test
    #   http.host = ENV['RABBITMQ_HOST']
    #   # http.port =
    #   # http.user_name =
    # end

    # - RABBITMQ_HOST=""
    # - RABBITMQ_PORT=""
    # - RABBITMQ_URL=${RABBITMQ_URL:-amqp://guest:guest@amqp:5672}
    # - RABBITMQ_VERSION=""
    # - RABBITMQ_USERNAME=${RABBITMQ_USERNAME:-guest}
    # - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-guest}
    server.amqp do |rabbitmq|
      rabbitmq.host = "localhost" # ENV['RABBITMQ_HOST']
      rabbitmq.vhost = "/" # ENV['RABBITMQ_VHOST']
      rabbitmq.port = "5672" # ENV['RABBITMQ_PORT']
      rabbitmq.url = "amqp://localhost:5672/" # ENV['RABBITMQ_URL']
      rabbitmq.user_name = "" # ENV['RABBITMQ_USERNAME']
      rabbitmq.password = "" # ENV['RABBITMQ_PASSWORD']
      rabbitmq.default_content_type = 'application/json'
    end

    server.amqp do |rabbitmq|
      rabbitmq.host = "localhost" # ENV['RABBITMQ_HOST']
      rabbitmq.vhost = "/event_source" # ENV['RABBITMQ_VHOST']
      rabbitmq.port = "5672" # ENV['RABBITMQ_PORT']
      rabbitmq.ref = "amqp://localhost:5672/event_source" # ENV['RABBITMQ_URL']
      rabbitmq.user_name = "" # ENV['RABBITMQ_USERNAME']
      rabbitmq.password = "" # ENV['RABBITMQ_PASSWORD']
      rabbitmq.default_content_type = 'application/json'
    end

    server.http do |http|
      http.host = "https://api.github.com"
      http.default_content_type = 'application/json'
    end

    server.http do |http|
      http.host = "http://localhost"
      http.port = "3000"
      http.default_content_type = 'application/json'
    end

    server.http do |http|
      http.ref = "https://impl.hub.cms.gov/Imp1"
      http.url = "https://impl.hub.cms.gov/Imp1"
      http.client_certificate do |client_cert|
        client_cert.client_certificate = File.join(
          File.dirname(__FILE__), "..", "cert_needs_pass.pem"
        )
        client_cert.client_key = File.expand_path(
          File.join(File.dirname(__FILE__), "..", "key_needs_pass.key")
        )
        client_cert.client_key_password = "testpasswd"
      end
      http.default_content_type = ENV['RIDP_CONTENT_TYPE'] || 'application/soap+xml'
      http.soap do |soap|
        soap.user_name = "aces user name"
        soap.password = "aces password"
        soap.password_encoding = :plain
        soap.use_timestamp = true
        soap.timestamp_ttl = 60.seconds
      end
    end

    # server.amqp do |amqp|
    #   amqp.url = "amqp://localhost:5672/"
    # end
  end

  # config.servers = [
  #   amqp: {

  #   },
  #   http: {

  #   }
  # ]

  # Server Options will be coming from ENV which will be set by Docker
  # config.servers = [
  #   {
  #     url: ENV['RABBITMQ_SERVER']
  #   },
  #   {
  #     url: ENV['RABBITMQ_SERVER']
  #   },
  # ]

  # config.asyncapi_resources = AcaEntities::AsyncApi::Mitc
  # config.asyncapi_resources = AcaEntities.find_resources_for(:enroll, %w[amqp]) # will give you resouces in array of hashes form
  # AcaEntities::Operations::AsyncApi::FindResource.new.call(self)
end

dir = Pathname.pwd.join('spec', 'support', 'async_api_files')
EventSource.async_api_schemas = ::Dir[::File.join(dir, '**', '*')].reject { |p| ::File.directory? p }.sort.reduce([]) do |memo, file|
  # read
  # serialize yaml to hash
  # Add to memo
  memo << EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath.new.call(path: file).success
end

EventSource.initialize!
