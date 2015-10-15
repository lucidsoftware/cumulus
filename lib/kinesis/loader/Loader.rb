require "common/BaseLoader"
require "conf/Configuration"
require "kinesis/models/StreamConfig"

module Cumulus
  module Kinesis
    module Loader

      include Common::BaseLoader

      @@streams_dir = Configuration.instance.kinesis.directory

      def self.streams
        Common::BaseLoader::resources(@@streams_dir, &StreamConfig.method(:new))
      end

    end
  end
end