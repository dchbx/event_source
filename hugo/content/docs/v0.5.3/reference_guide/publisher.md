---
title: Publisher
description: Aggregate and broadcast Events
---

Publishers are responsible for defining events that are broadcast to registered Subscribers. Below is a publisher class for Events that reference `publisher_path`: `'organizations.organization_publisher'`.

Notice the `EventSource::Publisher` Mixin and parameter. It indicates that this publisher will use AMQP protocol to exchange messages. The `:amqp` key's associated value: `organizations.organization_publisher` indicates the AMQP channel used to publish these event messages.

The `register_event` key enumerates events supported by this publisher class.

<!-- prettier_ignore_start -->

```ruby
# app/event_source/publishers/organizations/organization_publisher.rb

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
