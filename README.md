# EventSource: Event-enable your application's domain model

EventSource simplifies event-driven architecture design by adding helpers and interfaces that abstract away many of the underlying complexities associated with composing, publishing and subscribing to events - Event Sourcing Lite. The gem presents a standards-based DSL for configuring and exchanging event using multiple protocols within an application or between services.

EventSource supports the following protocols:

1. AMQP using [RabbitMQ](https://rabbitmq.com/) broker
2. HTTP and HTTP with SOAP extensions

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'event_source'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install event_source
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Configuration

EventSource's DSL applies the [AsyncAPi 2.0.0](https://www.asyncapi.com/docs/specifications/v2.0.0) specification for configuring the infrastucture environment and exchanging event messages. AsyncAPI components include:

- Servers
- Channels
- Operations
- Protocol-specific bindings at various levels

Using AsyncAPI definitions, EventSource enables your application to join message broker- and Web server- hosted networks, registering as a message producer and/or consumer, performing message publish and subscribe operations.

Following is an abbrevatiated example AsyncAPI YAML configuration file for accessing a service over HTTP protocol:

```yaml
asyncapi: "2.0.0"
---
servers:
  production:
    url: http://mitc:3001
    protocol: http
    protocolVersion: 0.1.0
    description: MitC Development Server

channels:
  /determinations/eval:
    publish:
      operationId: /determinations/eval
      description: HTTP endpoint for MitC eligibility determination requests
      bindings:
        http:
          type: request
          method: POST
          headers:
            Content-Type: application/json
            Accept: application/json
    subscribe:
      operationId: /on/determinations/eval
      description: EventSource Subscriber that publishes MitC eligibility determination responses
      bindings:
        http:
          type: response
          method: GET
          headers:
            Content-Type: application/json
            Accept: application/json
```

## Usage

EventSource enables these core components:

1. Event - notifications about something that happens in the system
2. Command - mixin to build and publish an Event
3. Publisher - aggregate and broadcast Events
4. Subscriber - consumers (listeners) for published Events

### Event

Events are signals about anything notable that happens in the system. For example, events can indicate that an enrollment period has begun, an eligibility determined, an application submitted and an enrollment effectuated. Event names use past tense form as a convention, for example: `Created`, `Updated`, `Deleted`.

Events are subclassed from the `EventSource::Event` class. An Event class must include a `publisher_path`. The `publisher_path` is a dot-notation, stringified class name that specifies the topic where event instances are published.

For example, the following event has a `publisher_path` referencing the `Organizations::OrganiztionPublisher` class. It also enumerates four `attribute_keys`: `:hbx_id, :legal_name, :fein, :entity_kind`.

```ruby
 # app/event_source/events/organizations/general_organization/created.rb

 class Organizations::GeneralOrganizationCreated < EventSource::Event
   publisher_path 'organizations.organization_publisher'
   attribute_keys :hbx_id, :legal_name, :fein, :entity_kind
   ...
 end
```

As shown in this example, an Event may optionally specify an Event payload's attribute keys by including `attribute_keys`. Note that this establishes a contract for attributes that must in an event's attribute payload. Each event must include a value for each the specified key. Missing key/value pairs will prevent publishing the event instance. Additional key/value pairs are ignored.

Events that don't specify `attribute_keys` do not validate and allow any passed key/value pairs as instance attributes.

Here's an example of an `Organizations::GeneralOrganizationCreated` instance:

<!-- prettier_ignore_start -->

```ruby
created_event = Organizations::GeneralOrganizationCreated.new
# => <Organizations::GeneralOrganizationCreated:0x00007fe642ff8748>

created_event.valid?
# => false

created_event.event_errors
# => ["missing required keys: [:hbx_id, :legal_name, :fein, :entity_kind]"]

created_event.attributes = {
  hbx_id: '12345',
  legal_name: 'ACME Corp',
  entity_kind: :c_corp,
  fein: '898784125',
}
# => {:hbx_id=>"12345", :legal_name=>"ACME Corp", :entity_kind=>:c_corp, :fein=>"898784125"}

created_event.valid?
# => true
```

<!-- prettier_ignore_end -->

### Command

Commands are an application's on-ramp to event-driven features. Mix `EventSource::Command` into any class to turn it into a Command and enable access to the DSL's Events.

<!-- prettier_ignore_start -->

```ruby
# app/operations/organizations/create_general_organization.rb

class Organizations::GeneralOrganizationCreate
 include EventSource::Command
 include Logging
 send(:include, Dry::Monads[:result, :do])
 send(:include, Dry::Monads[:try])

 def call(params)
   values = yield validate(params)
   organization = yield create_general_organization(values)
   event = yield publish_event(organization)
   Success(organization)
 end

 ...
end
```

<!-- prettier_ignore_end -->

Command names use imperative form, for example: `Create`, `Update`, `Delete`. Where they already exist, Operations developed using [Dry::Tranaction](https://dry-rb.org/gems/dry-transaction) mixin are likely candidates to extend as Commands.

Create events using the `event` keyword followed by a reference to its `event_key` - a stringified, dot-notation reference to an existing Event class. The system will raise a runtime error if an event matching the `event_key` isn't found.

For the following `publish_event` method, the Command will publish the event `organizations.general_organization_created`. Assigning a hash to the `attributes` option adds those key/value pairs to the event's message payload.

<!-- prettier_ignore_start -->

```ruby
def publish_event(organization)
  event =
    event 'organizations.general_organization_created',
          attributes: organization.to_h
  event.publish
  logger.info "Published event: #{event}"
end
```

<!-- prettier_ignore_end -->

### Publisher

Publishers are responsible for defining events that are broadcast to registered Subscribers. Below is a publisher class for Events that reference `publisher_path`: `'organizations.organization_publisher'`.

Notice the `EventSource::Publisher` Mixin and parameter. It indicates that this publisher will use AMQP protocol to exchange messages. The `:amqp` key's associated value: `organizations.organization_publisher` indicates the AMQP channel used to publish these event messages.

The `register_event` key enumerates events supported by this publisher class.

<!-- prettier_ignore_start -->

```ruby
# app/event_source/publishers/organizations/organization_publisher.rb

require 'dry/events/publisher'

class OrganizationPublisher
  include ::EventSource::Publisher[amqp: 'organizations.organization_events']

  register_event 'general_organization_created'
  register_event 'general_organization_fein_corrected'
  register_event 'general_organization_fein_updated'

  register_event 'exempt_organization_created'

  register_event 'address_updated'
end
```

<!-- prettier_ignore_end -->

EventSource includes protocol support for: `:amap`, `:http` and `:soap` over http. There's a seperate, necessary process for configuring protcols, channels and associated elements to enable event messaging. These elements must be declared in AsyncApi YAML files in the [AcaEntities repository](https://github.com/dchbx/aca_entities) for loading during service startup. Contact a senior developer or DevOps for more information.

### Subscriber

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

## File System Conventions

A good convention for Rails applications is to group EventSource components under the `app/` into three subfolders: `event_source`, `events` and `operations`. For example:

```ruby
enroll system

app
  |- contracts
  | |- organizations
  | | |- organization_contract.rb
  |- entities
  | |- organizations
  | | |- organization.rb
  |- event_source
  | |- events
  | | |- organizations
  | | | |- address_updated.rb
  | | | |- general_organization_created.rb
  | | | |- general_organization_fein_corrected.rb
  | | | |- general_organization_fein_updated.rb
  | |- subscribers
  | | |- polypress
  | | | |- enroll_medicaid_notices.rb
  | | |- medicaid_gateway
  | | | |- eligiblity_determinations.rb
  | |- publishers
  | | |- organizations
  | | | | |- organization_publisher.rb
  |- operations
  | |- organizations
  | | |- correct_or_update_general_organization_fein.rb
  | | |- create_general_organization_fein.rb
  | | |- update_address.rb
```

This structure will result in dot-namespaced values like the following:

```ruby
organizations.exempt_organization (entity)
organizations.general_organization (entity)
contracts.organizations.exempt_organization_contract (contract)
contracts.organizations.general_organization_contract (contract)
organizations.general_organization_model (model)
organizations.exempt_organization_model (model)
operations.organizations.create_general_organization (command / operation)
events.organizations.general_organization_created (event)
events.organizations.address_updated (event)
publishers.organizations.organizations_publisher (publisher)
subscribers.polypress.enroll_medicaid_notices_subscriber (subscriber)
subscribers.medicaid_gateway.eligiblity_determinations_subscriber (subscriber)
```

And Routing Keys like the following:

```ruby
medicaid_gateway: channal_item_name: magi_medicaid.mitc.eligibilities.determined_mixed_eligible:
medicaid_gateway: publish_operation_id: magi_medicaid.mitc.eligibilities.determined_mixed_eligible:
medicaid_gateway: publish_operation_id: magi_medicaid.mitc.eligibilities.determined_mixed_eligible:
medicaid_gateway exchange name (bindings): magi_medicaid.mitc.eligibilities
medicaid_gateway routing key (bindings): magi_medicaid.mitc.eligibilities.determined_mixed_eligible:
polypress subscriber: on_polypress.magi_medicaid.mitc.eligibilities

```

## Future

### EventStream

The current implementation supports event-based publish and subscribe (Pub/Sub) but doesn't cover EventStreams. Adding support for EventStreams is a project consideration. However, for many use cases EventStream features are overkill and introduces additional complexity and resources to build and operate. There also are other avialable options, including these projects:

- [Sequent](https://www.sequent.io/)
- [Eventide](https://eventide-project.org/)

### Elaborating Pub/Sub

```ruby
topic_publishers = [
  'Organizations.organizations.organization_publisher',
  'enrollment_publisher',
  'family_publisher',
  'marketplace.congress.cycle_event_publisher', # event => 'open_enfollment_begin'
  'marketplace.individual.cycle_event_publisher', # event => 'open_enfollment_begin'
  'marketplace.shop.cycle_event_publisher', # event => 'open_enfollment_begin'
  'system.timekeeper_publisher', # event => 'advance_date_of_record'
]

# provide default broadcast Publisher (Dispatcher) with ability to override
# supported by local subscibers that publish to enterprise
broadcast_publishers = %w[
  urgent
  each_minute
  beginning_of_day
  end_of_day
  hourly
  beginning_of_month
  silent_period
]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dchbx/event_source.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

```

```
