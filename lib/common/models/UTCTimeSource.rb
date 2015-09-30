module Cumulus
  module Common
    class UTCTimeSource

      # Make now always return now in UTC
      def now
        Time.now.utc
      end

      # Make local always use utc time
      def local(*args)
        Time.utc(*args)
      end

    end
  end
end