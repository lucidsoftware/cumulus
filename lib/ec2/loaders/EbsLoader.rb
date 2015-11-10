require "common/BaseLoader"
require "conf/Configuration"
require "ec2/models/EbsGroupConfig"

module Cumulus
  module EC2
    module EbsLoader

      include Common::BaseLoader

      @@groups_dir = Configuration.instance.ec2.ebs_directory

      def self.groups
        Common::BaseLoader::resources(@@groups_dir, &EbsGroupConfig.method(:new))
      end

    end
  end
end