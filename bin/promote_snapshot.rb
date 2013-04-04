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

report_error(parser, "Argument for --identity is missing") unless options[:identity]
report_error(parser, "Argument for --keypair is missing") unless options[:keypair]
report_error(parser, "Argument for --snapshot is missing") unless options[:snapshot]
report_error(parser, "Argument for --min-size is missing") unless options[:min]
report_error(parser, "Argument for --max-size is missing") unless options[:max]
report_error(parser, "Argument for --desired-capacity is missing") unless options[:capacity]

available_images = list_available_images
snapshot_options = available_images.keys.sort.reverse

available_groups = list_available_scaling_groups.sort.reverse
snapshot = nil

if !available_images[options[:snapshot]]
  report_error(parser, "Invalid snapshot name! \nAvailable options:\n " + snapshot_options.map{|x| "\t" + x}.join("\n"))
elsif !available_groups.member?(options[:snapshot])
  report_error(parser, "Snapshot #{options[:snapshot]} is not deployed.\nCurrently deployed: \n" + 
               available_groups.map{|x| "\t" + x}.join("\n"))
else
  snapshot = options[:snapshot]
  puts "AMI named #{options[:snapshot]} exists!"
end

unless check_launch_configuration(snapshot)
  report_error(parser, "Could not find launch config with name '#{snapshot}'")
else
  puts "AS launch config #{snapshot} exists!"
end

to_outset = available_groups.find_all{|x| x != snapshot}
unless to_outset.length > 0
  report_error(parser, "Snapshot #{snapshot} is already promoted")
else
  puts "Scheduled outsetting group(s): " + to_outset.join(", ")
end

raise Exception.new("NOT IMPLEMENTED!")

puts
update_scaling_group(snapshot, options[:min], options[:max], options[:capacity])
Dir.chdir(File.join(File.dirname(__FILE__), "..", "lib"))

to_outset.each do |snapshot_to_delete|
  instances = get_scaling_group_instances(snapshot_to_delete)
  update_scaling_group(snapshot_to_delete, 0, 0, instances.length)

  instances.each do |host,info|
    if info[:status] == 'running'
      
    end    
  end

  cmd = "\nas-delete-auto-scaling-group #{snapshot_to_delete} --force --force-delete"  
  system(cmd)
  raise Exception.new("Something bad happened") unless $?.exitstatus == 0
end

