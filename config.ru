require 'eventmachine'

class Poison
  def to_s
    raise '55'
  end
end

class DeferrableBody
  include EventMachine::Deferrable
  
  def initialize
    @queue = []
    # make sure to flush out the queue before closing the connection
    callback do
      until @queue.empty?
        @queue.shift.each{|chunk| @body_callback.call(chunk) }
      end
    end
  end
  
  def schedule_dequeue
    return unless @body_callback
    EventMachine::next_tick do
      next unless body = @queue.shift
      body.each do |chunk|
        @body_callback.call(chunk)
      end
      schedule_dequeue unless @queue.empty?
    end
  end 

  def call(body)
    puts "Call"
    @queue << body
    schedule_dequeue
  end

  def each &blk
    puts "Each "
    @body_callback = blk
    schedule_dequeue
  end

end

class AsyncApp
  AsyncResponse = [-1, {}, []].freeze
    
  def call(env)
    body = DeferrableBody.new
    
    # Get the headers out there asap, let the client know we're alive...
    EM.next_tick do
      env['async.callback'].call [200, {'Content-Type' => 'text/html'}, body]
      body.call ["Start your engines...\n"]
      puts "First reply"
    end
    
    # Semi-emulate a long db request, instead of a timer, in reality we'd be 
    # waiting for the response data. Whilst this happens, other connections 
    # can be serviced.
    # This could be any callback based thing though, a deferrable waiting on 
    # IO data, a db request, an http request, an smtp send, whatever.
    EM.add_periodic_timer(1) do
      body.call ["Woah, async!\n"]
    end
    
    AsyncResponse # Tells Thin to not close the connection and continue it's work on other request
  end
end

use Rack::Chunked
run AsyncApp.new
