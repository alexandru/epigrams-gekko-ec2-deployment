#!/usr/bin/env ruby

require 'optparse'
require File.absolute_path(File.join(File.dirname(__FILE__), "..", "lib", "utils"))

list_available_images.each do |item|
  puts "#{item[0]} - #{item[1]}"
end
