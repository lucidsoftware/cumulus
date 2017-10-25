module AwsUtil
  # Public: Static method that converts an array to an object that can be used in the
  # AWS API (with quantity and items)
  #
  # arr - the array to convert
  #
  # Returns an object with quantity and items
  def self.aws_array(arr)
    if arr.nil? || arr.empty?
      {
        quantity: 0,
        items: nil
      }
    else
      {
        quantity: arr.size,
        items: arr
      }
    end
  end

  # Public: Static method that returns nil if an array is empty
  #
  # arr - an array to conver
  #
  # Returns nil if the array is empty, or the original array otherwise
  def self.array_or_nil(arr)
    if arr.nil? || arr.empty?
      nil
    else
      arr
    end
  end

  def self.list_paged_results
    more = true
    marker = nil
    all_results = []
    while more do
      (result, more, marker) = yield(marker)
      all_results += result
    end
    all_results
  end
end
