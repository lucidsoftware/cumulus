require "conf/Configuration"

# Public: Provides methods for creating strings with different colors in the
# console.
class Colors
  @@colors_enabled = Configuration.instance.colors_enabled
  @@color_prefix = "\033["
  @@no_color = "#{@@color_prefix}0m"
  @@red = "#{@@color_prefix}0;31m"
  @@green = "#{@@color_prefix}0;32m"
  @@orange = "#{@@color_prefix}1;33m"
  @@blue = "#{@@color_prefix}1;34m"

  # Public: color format a string that describes an added resource
  #
  # s - the string to format
  #
  # Returns the formatted string
  def self.added(s)
    self.green(s)
  end

  # Public: color format a string that describes an unmanaged resource
  #
  # s - the string to format
  #
  # Returns the formatted string
  def self.unmanaged(s)
    self.red(s)
  end

  # Public: color format a string that describes the changes in AWS
  #
  # s - the string to format
  #
  # Returns the formatted string
  def self.aws_changes(s)
    self.blue(s)
  end

  # Public: color format a string that describes the local changes
  #
  # s - the string to format
  #
  # Returns the formatted string
  def self.local_changes(s)
    self.orange(s)
  end

  # Public: create a string that has a specific color. Will not output color
  # if `colors_enabled` is set to false. This can be set in "configuration.json"
  #
  # s     - the string to format
  # color - the color to use
  #
  # Returns the formatted string
  def self.colorize(s, color)
    if @@colors_enabled
      "#{color}#{s}#{@@no_color}"
    else
      s
    end
  end

  # Public: Create a string that is red.
  #
  # s - the string to format
  #
  # Returns the red string
  def self.red(s)
    Colors.colorize(s, @@red)
  end

  # Public: Create a string that is green.
  #
  # s - the string to format
  #
  # Returns the green string
  def self.green(s)
    Colors.colorize(s, @@green)
  end

  # Public: Create a string that is blue.
  #
  # s - the string to format
  #
  # Returns the blue string
  def self.blue(s)
    Colors.colorize(s, @@blue)
  end

  # Public: Create a string that is orange.
  #
  # s - the string to format
  #
  # Returns the orange string
  def self.orange(s)
    Colors.colorize(s, @@orange)
  end
end
