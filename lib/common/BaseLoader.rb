require "json"

# Public: A module that handles loading all the 4 configuration files and
# creating objects from them.
module BaseLoader
  # Internal: Load the resources in a directory, handling each file with the
  # function passed in.
  #
  # dir               - the directory to load resources from
  # individual_loader - the function that loads a resource from each file name
  #
  # Returns an array of resources
  def BaseLoader.resources(dir, &individual_loader)
    Dir.entries(dir)
    .reject { |f| f == "." or f == ".." or File.directory?(File.join(dir, f)) }
    .map { |f| BaseLoader.resource(f, dir, &individual_loader) }
  end

  # Internal: Load the resource, passing the parsed JSON to the function passed
  # in
  #
  # file    - the name of the file to load
  # dir     - the directory the file is located in
  # loader  - the function that will handle the read json
  def BaseLoader.resource(file, dir, &loader)
    loader.call(JSON.parse(File.read(File.join(dir, file))))
  end
end
