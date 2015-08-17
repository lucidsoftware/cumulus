Vpc = Struct.new(:id, :region) do
  # Public: Implement <=> to allow sorting. Sorts by id and then region
  def <=>(other)
    if self.id == other.id
      self.region <=> other.region
    else
      self.id <=> self.id
    end
  end

  # Public: Produce a hash representing the VPC
  #
  # Returns the hash
  def to_hash
    {
      "id" => id,
      "region" => region
    }
  end
end
