
require "iam/models/ResourceWithPolicy"
# Public: Represents a config file for a role. Will lazily load its static and
# template policies as needed.
class RoleConfig < ResourceWithPolicy

  attr_accessor :policy_document

  # Public: Constructor.
  #
  # name - the name of the role
  # json - the Hash containing the JSON configuration for this RoleConfig, if
  #        nil, this will be an "empty RoleConfig"
  def initialize(name = nil, json = nil)
    super(name, json)
    @policy_document = Loader.policy_document(json["policy-document"]) unless json.nil?
    @type = "role"
  end

  def hash
    h = super()
    h["policy-document"] = @policy_document
    h
  end

end
