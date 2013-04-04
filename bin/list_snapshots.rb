#!/usr/bin/env ruby

require 'optparse'
require_relative "../lib/utils"

available = list_available_images
names = available.keys.sort.reverse

names.each do |name|
  puts "#{name} - #{available[name]}"
end
