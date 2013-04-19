#!/usr/bin/env ruby

require 'optparse'
require_relative "../lib/utils"
require_relative "../lib/commands"

options = {}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on("-s", "--snapshot STRING", "Snapshot name") do |snapshot|
    options[:snapshot] = snapshot
  end

  opts.on("--min-size NUMBER", "Minimum number of instances to create in the auto-scaling group") do |min_nr|
    options[:min] = min_nr.to_i
  end

  opts.on("--max-size NUMBER", "Maximum number of instances to create in the auto-scaling group") do |max_nr|
    options[:max] = max_nr.to_i
  end

  opts.on("--desired-capacity NUMBER", "Desired capacity for the auto-scaling group") do |capacity|
    options[:capacity] = capacity.to_i
  end
end

parser.parse!

report_error(parser, "Argument for --snapshot is missing") unless options[:snapshot]
report_error(parser, "Argument for --min-size is missing") unless options[:min]
report_error(parser, "Argument for --max-size is missing") unless options[:max]
report_error(parser, "Argument for --desired-capacity is missing") unless options[:capacity]

available_images = list_available_images
snapshot_options = available_images.keys.sort.reverse
snapshot = nil

unless available_images[options[:snapshot]]
  report_error(parser, "Invalid snapshot name! \nAvailable options:\n " + snapshot_options.map{|x| "\t" + x}.join("\n"))
else
  snapshot = options[:snapshot]
  puts "AMI named #{options[:snapshot]} exists!"
end

unless check_launch_configuration(snapshot)
  report_error(parser, "Could not find launch config with name '#{snapshot}'")
else
  puts "AS launch config #{snapshot} exists!"
end

check_existing = `as-describe-auto-scaling-groups #{snapshot} 2>&1`.strip
unless check_existing.index(snapshot)
  $stdout.puts("ERROR: no auto-scaling group active for snapshot #{snapshot}")
  $stdout.puts(check_existing)
  exit(1)
else
  puts "AS Group #{snapshot} is deployed!"
end

Commands.update_deployed_snapshot(snapshot, options[:min], options[:max], options[:capacity])

puts "\nDone!"
