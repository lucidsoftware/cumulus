require "iam/models/ResourceWithPolicy"

# Public: Represents a config file for a user. Lazily loads its static and
# template policies as needed.
class UserConfig < ResourceWithPolicy

  # Public: Constructor
  #
  # json - the Hash containing the JSON configuration for this UserConfig
  def initialize(json)
    super(json)
    @type = "user"
  end
  
end
