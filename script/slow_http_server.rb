#!/usr/bin/env ruby

# code stolen from http://www.igvita.com/2008/05/27/ruby-eventmachine-the-speed-demon/

require 'rubygems'
require 'bundler'
require 'eventmachine'
require 'evma_httpserver'

class Handler < EventMachine::Connection
  include EventMachine::HttpServer

  def process_http_request
    resp = EventMachine::DelegatedHttpResponse.new(self)

    # Block which fulfills the request
    operation = proc do
      sleep 5 # simulate a long running request
      resp.status = 200
      resp.content = "okay"
    end

    # Callback block to execute once the request is fulfilled
    callback = proc do |res|
      resp.send_response
    end

    # Let the thread pool (20 Ruby threads) handle request
    EM.defer(operation, callback)
  end
end

EventMachine::run {
  EventMachine::start_server('0.0.0.0', 3001, Handler)
  puts "Listening..."
}
