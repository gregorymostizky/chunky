require 'eventmachine'

class DeferrableBody
  include EventMachine::Deferrable

  def initialize
    @queue = []
      # make sure to flush out the queue before closing the connection
    callback do
      until @queue.empty?
        @queue.shift.each { |chunk| @body_callback.call(chunk) }
      end
    end
  end

  def schedule_dequeue

    # Can't return here - need to wait for actual data somehow?

    return unless @body_callback
    return unless body = @queue.shift
    puts "deq #{body}"
    body.each do |chunk|
      @body_callback.call(chunk)
    end
    EventMachine::next_tick do
      schedule_dequeue unless @queue.empty?
    end
  end

  def call(body)
    puts "Call #{body}"
    @queue << body
    schedule_dequeue
  end

  def each &blk
    puts "Each "
    @body_callback = blk
    schedule_dequeue
  end

end

app = lambda do |env|
  #body_generator = ["123"]

  body_generator = DeferrableBody.new
  body_generator.call ["welcome"]
  EM.next_tick do
    body_generator.call ["hehe"]
  end

  [
      200,
      {'content-type' => 'text/html'},
      body_generator
  ]
end

run Rack::Chunked.new(app)

#run app