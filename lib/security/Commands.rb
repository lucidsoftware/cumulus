module Cumulus
  module SecurityGroups
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.usage_message
        "Usage: cumulus security-groups [diff|help|list|migrate|sync] [asset]"
      end

      def self.manager
        require "security/manager/Manager"
        Cumulus::SecurityGroups::Manager.new
      end

      def self.banner_message
        [
          "security-groups: Manage EC2 Security Groups",
          "\tDiff and sync EC2 security group configuration with AWS.",
        ].join("\n")
      end

    end
  end
end
