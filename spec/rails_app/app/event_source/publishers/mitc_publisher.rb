# frozen_string_literal: true

module Publishers
  class MitcPublisher
    # Publisher will send request payload to MiTC for determinations
    include ::EventSource::Publisher[http: '/determinations/eval']
    register_event '/determinations/eval'
  end
end
