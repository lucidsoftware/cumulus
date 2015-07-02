require "iam/models/ResourceWithPolicy"

# Public: Represents a config file for a user. Lazily loads its static and
# template policies as needed.
class UserConfig < ResourceWithPolicy

  # Public: Constructor
  #
  # name - the name of the user
  # json - the Hash containing the JSON configuration for this UserConfig, if
  #        nil, this will be an "empty UserConfig"
  def initialize(name = nil, json = nil)
    super(name, json)
    @type = "user"
  end

end
