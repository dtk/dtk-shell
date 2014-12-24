dtk_require_from_base('util/os_util')

module DTK
  module Shell
    class MessageQueue
      include Singleton

      MESSAGE_TYPES = [:info, :warn, :error]

      def initialize
        @queue = {}
        init_or_clear()
      end

      def self.process_response(response_obj)
        self.instance.process_response(response_obj)
      end

      def self.print_messages()
        self.instance.print_messages()
      end

      def init_or_clear()
        MESSAGE_TYPES.each { |msg_type| @queue[msg_type] = [] }
      end

      def print_messages()
        @queue[:info].each  { |msg| DTK::Client::OsUtil.print(msg, :white) }
        @queue[:warn].each  { |msg| DTK::Client::OsUtil.print(msg, :yellow) }
        @queue[:error].each { |msg| DTK::Client::OsUtil.print(msg, :red) }

        init_or_clear()
      end

      def process_response(response_obj)
        MESSAGE_TYPES.each do |msg_type|
          msg = response_obj[msg_type.to_s] || response_obj[msg_type]
          @queue[msg_type] << msg if msg
        end
      end

    end
  end
end
