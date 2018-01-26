require "s3/models/DefaultEncryptionDiff"

module Cumulus
  module S3
    class DefaultEncryptionConfig
      attr_reader :algorithm
      attr_reader :kms_master_key_id

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration.
      def initialize(json = nil)
        if json
          @algorithm = json["algorithm"]
          @kms_master_key_id = json["kms_master_key_id"]
        end
      end

      def to_aws
        {
          sse_algorithm: @algorithm,
          kms_master_key_id: @kms_master_key_id
        }
      end

      def to_h
        {
          "algorithm" => @algorithm,
          "kms_master_key_id" => @kms_master_key_id
        }
      end

      def diff(aws)
        diffs = []
        if @algorithm != aws.algorithm
          diffs << DefaultEncryptionDiff.new(DefaultEncryptionChange::ALGORITHM, aws, self)
        end
        if @kms_master_key_id != aws.kms_master_key_id
          diffs << DefaultEncryptionDiff.new(DefaultEncryptionChange::KMS_KEY, aws, self)
        end

        diffs
      end

      def populate!(aws)
        @algorithm = aws.sse_algorithm
        @kms_master_key_id = aws.kms_master_key_id
      end

      def ==(other)
        other.is_a?(DefaultEncryptionConfig) && @algorithm == other.algorithm && @kms_master_key_id == other.kms_master_key_id
      end

      def !=(other)
        !(self == other)
      end
    end
  end
end
