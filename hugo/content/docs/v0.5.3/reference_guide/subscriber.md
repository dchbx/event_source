---
title: Subscriber
description: Consumers (listeners) for broadcasted Events
---

Subscribers listen for events and enable reactors. Mix `EventSource::Subscriber` to include the Subscriber DSL. The parameter indicates the EventSource Protocol and PublishOperation `amqp: 'organizations.organization_events'`

The following example illustrates how the Polypress microservice may access events broadcast by the publisher above. First, some assumptions:

1. The source service, Enroll App for example, publishes events over AMQP protocol using the channel: `organizations.organization_events`

2. An AMQP AsyncAPI YAML file in the [AcaEntities repository](https://github.com/dchbx/aca_entities) for Enroll App configures a Channel Item and Publish Operation for `organizations.organization_events`

3. An AMQP AsyncAPI YAML file in the [AcaEntities repository](https://github.com/dchbx/aca_entities) for Polypress configures a Channel Item and Subscribe Operation for `on_polypress.organizations.organization_events`

4. The respective AMQP AsyncAPI file configurations include bindings for event message durability, acknowledgement and related settings.

In the code example below, a Polypress `subscribe` block binds to the `on_polypress_general_organization_created` event. When the Enroll App publishes a matching event message, the Polypress process subscription block calls `::Operations.GenerateNotice`.

<!-- prettier_ignore_start -->

```ruby
# app/event_source/subscribers/enroll/organizations/organization_subscriber.rb

class OrganizationSubscriber
  include EventSource::Logging
  include ::EventSource::Subscriber[amqp: 'organizations.organization_events']

  subscribe(
    :on_polypress_general_organization_created,
  ) do |delivery_info, metadata, event|
    event = JSON.parse(event, symbolize_names: true)
    result = ::Operations.GenerateNotice('new_general_organization').call(event)

    if result.success?
      ack(delivery_info.delivery_tag)
      logger.info "Polypress acknowledged amqp message: #{event}"
    else
      nack(delivery_info.delivery_tag)
      results
        .map(&:failure)
        .compact
        .each do |result|
          errors = result.failure.errors.to_h
          routing_key = delivery_info[:routing_key]
          logger.error(
            "Polypress: on_polypress_organizations_general_organization_created_subscriber_error;
nacked due to:#{errors}; for routing_key: #{routing_key}, event: #{event}",
          )
        end
    end
  rescue StandardError => e
    nack(delivery_info.delivery_tag)
    logger.error "Polypress: on_polypress_organizations_general_organization_created_subscriber_error: backtrace: #{e.backtrace}; nacked"
  end
end
```

In this case, the code synchronously processes the operation, branching flow based on the operation result:

1. Operation returns a Success monad: the event message is acknowledged to the AMQP broker which removes the message from the queue. The successful result is recorded by the application logger.

2. Operation returns a Failure monad: the event message is negatively-acknowledged to the AMQP broker which will follow configuration instructions to either retuen message to the queue or forward to a dead letter queue. The negative result is recorded by the application logger.

3. An unhandled exception is raised. The AMQP broker will follow configuration instructoins to either retuen message to the queue or forward to a dead letter queue. The negative result is sent to the application logger. The exception is recorded by the application logger.

<!-- prettier_ignore_end -->

Where event message ack/naks aren't necessary asynchronous actions like the example below are preferred as they don't block the process waiting for an operation to complete.

<!-- prettier_ignore_start -->

```ruby
subscribe(:on_organization_address_updated) do |delivery_info, metadata, event|
  event = JSON.parse(event, symbolize_names: true)

  # Set of independent reactors that choreograph each intended operation to execute asynchronously
  def on_address_updated(event)
    UpdateOrganizationJob.perform_later(event)
    ...
  end
end

```

<!-- prettier_ignore_end -->
