require 'dry/inflector'

module EventSource
  module Subscriber
    def self.included(base)
      base.extend ClassMethods

      TracePoint.trace(:end) do |t|
        if base == t.self
          base.subscribe
          t.disable
        end
      end
    end

    module ClassMethods
      attr_reader :publishers, :async_publishers

      def subscriptions(*args)
      	@publishers = [] unless defined? @publishers
        @publishers += args
      end

      def subscription(key, options = {})
        @publishers = [] unless defined? @publishers
        @async_publishers = {} unless defined? @async_publishers

        is_async = options.dig(:async, :enabled) || true

        if is_async
          @async_publishers[key] = options
        else
          @publishers << key
        end
      end

      def perform(event, subscriber)
        subcriber.on_oraganization_create(event)
      end

      def subscribe
        publishers.each do |publisher_key|
          publisher = publisher_for(publisher_key)
          publisher.subscribe(self.new)
        end

        async_publishers.each do |publisher_key, options|
          publisher = publisher_for(publisher_key)
          publisher.subscribe(options.dig(:async, :event)) do |event|
            listener_job = options.dig(:async, :job) || 'ListenerJob'
            listener_job.constantize.perform_now(event, self)
          end
        end
      end

      def publisher_for(publisher_key)
        pub_key_parts = publisher_key.split('.')
        # pub_klass = pub_key_parts.collect{|segment| EventSource::Inflector.camelize(segment)}.join('::').constantize
        pub_const = pub_key_parts.map(&:upcase).join('_')
        pub_const.constantize
        # raise error PublisherNotDefined
      end
    end
  end
end
