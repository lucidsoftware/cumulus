module Cumulus
  module Kinesis
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        format_message [
          "kinesis: Manage Kinesis Streams",
          "\tDiff and sync Kinesis configuration with AWS.",
        ]
      end

      def self.manager
        require "kinesis/manager/Manager"
        Cumulus::Kinesis::Manager.new
      end

    end
  end
end
