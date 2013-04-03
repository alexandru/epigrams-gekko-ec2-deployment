#!/usr/bin/env ruby

require 'optparse'
require File.absolute_path(File.join(File.dirname(__FILE__), "..", "lib", "utils"))

options = {}

def report_error(parser, msg)  
  $stderr.puts("\nERROR: #{msg}\n\n")
  $stderr.puts(parser)
  $stderr.puts
  exit(1)
end

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

  opts.on("-n", "--name-prefix=STRING", "Name prefix for the newly created AMI") do |n|
    options[:name_prefix] = n.gsub(/\W+/, '-')
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
report_error(parser, "Argument for --name-prefix is missing") unless options[:name_prefix]
report_error(parser, "--keypair could not be verified (probably invalid)") unless get_keypairs.member?(options[:keypair])

report_error(parser, "Environment variable AWS_ACCESS_KEY is not set") unless ENV['AWS_ACCESS_KEY']
report_error(parser, "Environment variable AWS_SECRET_KEY is not set") unless ENV['AWS_SECRET_KEY']

Dir.chdir(File.dirname(__FILE__))

puts "Creating instance ..."
instance_id = create_instances(options[:keypair], 1, options[:name_prefix], options[:ami])[0]
puts "Created instance ID: #{instance_id}"

begin
  host = wait_running(instance_id)

  fab_cmd = "fab -n 10 -u ubuntu -i #{options[:identity]} -H #{host} provision"
  puts "Provisioning instance ... #{fab_cmd}"
  raise Exception.new("Something wrong happened") unless system(fab_cmd)

  puts "Create AMI ..."

  ami_info = create_ami(instance_id, options[:name_prefix])
  ami_id, ami_name = ami_info[0], ami_info[1]

  wait_available_ami(ami_id)

  create_launch_config(ami_id, ami_name)
ensure
  system("ec2-terminate-instances #{instance_id}")
end

puts "\nDone!"




