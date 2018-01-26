require 's3/models/DefaultEncryptionConfig'

module AwsExtensions
  module S3
    module ServerSideEncryptionByDefault
      def to_cumulus
        cumulus = Cumulus::S3::DefaultEncryptionConfig.new
        cumulus.populate!(self)
        cumulus
      end
    end
  end
end

