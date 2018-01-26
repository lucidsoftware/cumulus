require 'common/models/Diff'
require "util/Colors"

module Cumulus
  module S3
    module DefaultEncryptionChange
      include Common::DiffChange

      ALGORITHM = Common::DiffChange.next_change_id
      KMS_KEY = Common::DiffChange.next_change_id
    end

    class DefaultEncryptionDiff < Common::Diff
      include DefaultEncryptionChange

      def asset_type
        "S3 Default Encryption"
      end

      def aws_name
        "Configuration"
      end

      def local_name
        "Configuration"
      end

      def diff_string
        case @type
        when ALGORITHM
          "Algorithm: AWS - #{Colors.aws_changes(@aws.algorithm)}, Local - #{Colors.local_changes(@local.algorithm)}"
        when KMS_KEY
          "KMS key id: AWS -#{Colors.aws_changes(@aws.kms_master_key_id)}, Local - #{Colors.local_changes(@local.kms_master_key_id)}"
        end
      end
    end
  end
end
