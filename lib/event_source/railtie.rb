# frozen_string_literal: true

module EventSource
  # :nodoc:
  module Railtie
    Rails::Application::Finisher.initializer "event_source.boot", after: :finisher_hook do
      EventSource.initialize!
    end
  end
end
