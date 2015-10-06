module Cumulus

  # Public: Provide methods for setting the status code that
  #         Cumulus should exit with
  module StatusCodes

    # Indicates that we are exiting normally
    OK = 0

    # Indicates there was an exception during execution
    EXCEPTION = 1

    # Indicates that there were diffs
    DIFFS = 2

    # Indicates that there were diffs and they were synced
    SYNC_DIFFS = 3

    # Static attributes and methods for keeping track of status codes
    class << self
      # Holds the value for the current status
      @@CURRENT_STATUS = OK

      # Public: Sets the status code if it is more severe than the current status code
      def set_status(status)

        # Only set the status if we are not already in exception state
        if @@CURRENT_STATUS != EXCEPTION

          # Only set the status if it is more severe (higher) than the current status
          if status > @@CURRENT_STATUS
            @@CURRENT_STATUS = status
          end

        end
      end

      # On exit, if the exit was successful, exit with the
      # status codes that describes what happened while running
      at_exit  do

        if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
          exit @@CURRENT_STATUS
        end

      end

    end

  end
end
