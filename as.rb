require 'sinatra/async'

class Long < Sinatra::Base
  register Sinatra::Async

  aget '/' do
    #body "asdasda"

    EM.add_periodic_timer(1) do
      async_schedule do
        body {"hehe\n"}
      end
    end
  end


end
