require "iam/models/ResourceWithPolicy"

# Public: Represents a config file for a user. Lazily loads its static and
# template policies as needed.
class UserConfig < ResourceWithPolicy

  # Public: Constructor
  #
  # json - the Hash containing the JSON configuration for this UserConfig, if
  #        nil, this will be an "empty UserConfig"
  def initialize(json = nil)
    super(json)
    @type = "user"
  end

end
