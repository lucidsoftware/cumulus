require "util/StatusCodes"

module Cumulus
  module Test
    module MockedStatusCodes
      def self.included(base)
        base.instance_eval do
          def set_status(status)
            if status == StatusCodes::EXCEPTION
              @@CURRENT_STATUS = StatusCodes::EXCEPTION
            end
          end
        end
      end
    end
  end
end
