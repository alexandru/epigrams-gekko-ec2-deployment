#!/usr/bin/env ruby

require 'optparse'
require_relative "../lib/utils"
require_relative "../lib/commands"

options = {}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on("-k", "--keypair NAME", "KeyPair to use when creating the instance") do |kp|
    options[:keypair] = kp.strip
  end

  opts.on("-i", "--identity FILE", 
          "Path to private credentials file for connecting to instances") do |i|
    report_error(opts, "Argument for --identity is not a file") unless File.exists?(i)
    options[:identity] = i
  end

  opts.on("-a", "--ami [STRING]", "Optional AMI ID (otherwise it starts from scratch)") do |ami|
    if ami && ami != ""
      options[:ami] = ami
    else
      options[:ami] = nil
    end
  end
end

parser.parse!

report_error(parser, "Argument for --identity is missing") unless options[:identity]
report_error(parser, "Argument for --keypair is missing") unless options[:keypair]
report_error(parser, "--keypair could not be verified (probably invalid)") unless get_keypairs.member?(options[:keypair])

ami_name = Commands.create_snapshot(options[:keypair], options[:identity], options[:ami])

puts "\Success: #{ami_name}"




