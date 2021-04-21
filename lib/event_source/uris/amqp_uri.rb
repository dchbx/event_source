# frozen_string_literal: true
require 'uri'

module URI
  class AMQP < Generic
    DEFAULT_PORT = 5672
  end
  @@schemes['AMQP'] = AMQP
end
