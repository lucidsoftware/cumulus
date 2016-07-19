module Cumulus
  module SecurityGroups
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.manager_name
        "security-groups"
      end

      def self.manager
        require "security/manager/Manager"
        Cumulus::SecurityGroups::Manager.new
      end

      def self.banner_message
        format_message [
          "security-groups: Manage EC2 Security Groups",
          "\tDiff and sync EC2 security group configuration with AWS.",
        ]
      end

    end
  end
end
