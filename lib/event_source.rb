require 'event_source/version'
require 'event_source/error'
require 'date'

require 'dry/types/type'
require 'dry/monads'
require 'dry/monads/do'
require 'dry/monads/result'
require 'dry/validation'
require 'dry-struct'

# TODO Remove ActiveSupport dependency
require 'active_support/all'

require 'event_source/inflector'
require 'event_source/metadata'
require 'event_source/command'
require 'event_source/publisher'
require 'event_source/attribute'
require 'event_source/event'
require 'event_source/subscriber'

module EventSource
  class << self
    attr_writer :logger

    # Set up logging: first attempt to attach to host application logger instance, otherwise
    # use local
    def logger
      @logger ||= Logger.new($stdout).tap { |log| log.progname = self.name }
    end
  end
end
