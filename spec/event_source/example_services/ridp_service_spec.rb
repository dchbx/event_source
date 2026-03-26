# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "An example service for RIDP" do
  let(:async_api_file) do
    Pathname.pwd.join(
      'spec',
      'support',
      'asyncapi',
      'ridp_services.yml'
    )
  end
  let(:config) do
    EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
      .new
      .call(path: async_api_file)
      .value!
  end

  before(:each) do
    EventSource::ConnectionManager.instance.drop_connections_for(:http)
    EventSource::ConnectionManager.instance.drop_connections_for(:amqp)
    EventSource.create_connections
  end

  let(:connection_manager) { EventSource::ConnectionManager.instance }

  let(:connection) do
    EventSource::ConnectionManager.instance.fetch_connection(config.servers.first)
  end

  let(:connection_proxy) do
    connection.connection_proxy
  end

  let(:channel) { config.channels.first }

  let(:es_channel) do
    connection.add_channel(channel.id, channel)
  end

  let(:channel_proxy) do
    es_channel.channel_proxy
  end

  let(:request_proxy) do
    channel_struct = EventSource::AsyncApi::ChannelItem.new(channel)
    EventSource::Protocols::Http::FaradayRequestProxy.new(channel_proxy, channel_struct)
  end

  before :each do
    stub_request(:post, "https://impl.hub.cms.gov/Imp1/RIDPService").with(
      headers: {
        'Accept'=>'*/*',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'User-Agent' => 'Faraday v1.4.3'
      }
    )
    .with do |request|
      puts request.body.inspect
      xml = Nokogiri::XML(request.body)
      u_token = xml.at_xpath(
        "/soap:Envelope/soap:Header/wsse:Security/wsse:UsernameToken",
        EventSource::Protocols::Http::Soap::XMLNS
      )
      t_stamp = xml.at_xpath(
        "/soap:Envelope/soap:Header/wsse:Security/wsu:Timestamp",
        EventSource::Protocols::Http::Soap::XMLNS
      )
      u_token.present? && t_stamp.present?
    end
    .to_return(status: 200, body: "", headers: {})
  end

  it "responds to requests" do
    request_proxy.publish
  end

  it "resolves connections" do
    config
    conn = connection_manager.fetch_connection(config.servers.first)
    expect(conn).not_to be_nil
  end
end 