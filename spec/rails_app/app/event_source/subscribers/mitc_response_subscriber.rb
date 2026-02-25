# frozen_string_literal: true

module Subscribers
  class MitcResponseSubscriber
    include ::EventSource::Subscriber[http: '/determinations/eval']
    extend EventSource::Logging

    subscribe(:on_determinations_eval) do |body, status, headers|
      $GLOBAL_TEST_FLAG = true
    end
  end
end
