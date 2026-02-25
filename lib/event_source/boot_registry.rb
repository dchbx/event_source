# frozen_string_literal: true

require 'set'
require 'monitor'

module EventSource
  # This class manages correct/loading of subscribers and publishers
  # based on the current stage of the EventSource lifecycle.
  #
  # Depending on both the time the initialization of EventSource is invoked
  # and when subscriber/publisher code is loaded, this can become complicated.
  # This is largely caused by two confounding factors:
  # 1. We want to delay initialization of EventSource until Rails is fully
  #    'ready'
  # 2. Based on the Rails environment, such as production, development, or
  #    test (primarily how those different environments treat lazy vs. eager
  #    loading of classes in a Rails application), subscriber and publisher
  #    code can be loaded before, after, or sometimes even DURING the
  #    EventSource boot process - we need to support all models
  class BootRegistry
    def initialize
      @unbooted_publishers = Set.new
      @unbooted_subscribers = Set.new
      @booted_publishers = Set.new
      @booted_subscribers = Set.new
      # This is our re-entrant mutex.  We're going to use it to make sure that
      # registration and boot methods aren't allowed to simultaneously alter
      # our state.  You'll notice most methods on this class are wrapped in
      # synchronize calls against this.
      @bootex = Monitor.new
      @booted = false
    end

    def boot!(force = false)
      @bootex.synchronize do
        return if @booted && !force
        yield
        boot_publishers!
        boot_subscribers!
        @booted = true
      end
    end

    # Register a publisher for EventSource.
    #
    # If the EventSource hasn't been booted, save publisher for later.
    # Otherwise, boot it now.
    def register_publisher(publisher_klass)
      @bootex.synchronize do
        if @booted
          publisher_klass.validate
          @booted_publishers << publisher_klass
        else
          @unbooted_publishers << publisher_klass
        end
      end
    end

    # Register a subscriber for EventSource.
    #
    # If the EventSource hasn't been booted, save the subscriber for later.
    # Otherwise, boot it now.
    def register_subscriber(subscriber_klass)
      @bootex.synchronize do
        if @booted
          subscriber_klass.create_subscription
          @booted_subscribers << subscriber_klass
        else
          @unbooted_subscribers << subscriber_klass
        end
      end
    end

    # Boot the publishers.
    def boot_publishers!
      @bootex.synchronize do
        @unbooted_publishers.each do |pk|
          pk.validate 
          @booted_publishers << pk
        end
        @unbooted_publishers = Set.new
      end
    end

    # Boot the subscribers.
    def boot_subscribers!
      @bootex.synchronize do
        @unbooted_subscribers.each do |sk|
          sk.create_subscription
          @booted_subscribers << sk
        end
        @unbooted_subscribers = Set.new
      end
    end
  end
end