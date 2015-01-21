module DTK::Client
  module Poller

    PERIOD_WAIT_TIME = 1

    def poller_response(wait_time = PERIOD_WAIT_TIME)
      begin
        response = nil
        thread   = Thread.new(self) do |main_thread|
          begin
            while true
              messages_response = main_thread.get main_thread.rest_url("messages/retrieve")
              print_response(messages_response.data) if messages_response.ok?
              sleep(wait_time)
            end
          rescue => e
            puts e.message
            pp e.backtrace
          end
        end

        response = yield
      ensure
        thread.kill
      end
      response
    end

    def print_response(message_array)
      message_array.each do |msg|
        DTK::Client::OsUtil.print(msg['message'], resolve_type(msg['type']))
      end
    end

    def resolve_type(message_type)
      case message_type.to_sym
      when :info
        :white
      when :warning
        :yellow
      when :error
        :red
      else
        :white
      end
    end
  end
end