require 'concurrent'

module Concurrent
  class ThreadPoolExecutor
    def post_with_error(&f)
      post do 
        begin
          f.call()
        rescue => e
          unless defined? @error
            @error = e
            shutdown
          end
        end
      end
    end
    def shutdown_and_wait
      shutdown
      wait_for_termination
      if defined? @error
        raise @error
      end
    end
  end
end
