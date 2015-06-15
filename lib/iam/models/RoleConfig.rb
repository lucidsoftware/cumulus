require "iam/models/ResourceWithPolicy"

# Public: Represents a config file for a role. Will lazily load its static and
# template policies as needed.
class RoleConfig < ResourceWithPolicy

  attr_reader :policy_document

  # Public: Constructor.
  #
  # json - the Hash containing the JSON configuration for this RoleConfig
  def initialize(json)
    super(json)
    @policy_document = Loader.policy_document(json["policy-document"])
    @type = "role"
  end

end
