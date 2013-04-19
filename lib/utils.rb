require 'date'
require_relative "../config"

def report_error(parser, msg)  
  $stderr.puts("\nERROR: #{msg}\n\n")
  $stderr.puts(parser)
  $stderr.puts
  exit(1)
end


def get_keypairs
  out = `ec2-describe-keypairs 2>&1`
  match = out.scan(/KEYPAIR\s+(\S+)/)  
  match.map{|x| x[0]}
end

def create_instances(keypair, nr, tag_name, ami_id=nil)
  ami_id ||= Gekko::Config::DEFAULT_AMI # ubuntu 12.04 LTS

  ids = []
  (0...nr).each do |i|
    out = `ec2-run-instances #{ami_id} -k #{keypair} --monitor -n 1 -t #{Gekko::Config::INSTANCE_TYPE} -g #{Gekko::Config::GROUP} --instance-initiated-shutdown-behavior stop 2>&1`
    match = out.scan(/INSTANCE\s+(i[-]\S+)/)
    raise Exception.new("Could not create instance: #{out}") unless match && match.length == 1
    `ec2-create-tags #{match[0][0]} --tag Name=#{tag_name}`
    ids << match[0][0]
  end
  ids
end

def wait_running(instance_id)
  while true
    out = `ec2-describe-instances --show-empty-fields #{instance_id} 2>&1`
    status = out.split(/\r?\n/)[1].split(/\s+/)
    raise Exception.new("Error when pooling instance status: #{out}") unless status && status.length > 1 && status[0] == "INSTANCE"
    return status[3] if status[5] == "running"
    puts "Waiting for new instance to start (#{instance_id}: #{status[5]})"
    sleep(3)
  end
end

def create_ami(instance_id, name_prefix)
  ts = DateTime.now.strftime("%Y%m%d-%H%M%S")
  name = "#{name_prefix}-#{ts}"

  out = `ec2-create-image --region us-east-1 #{instance_id} --name #{name} 2>&1`
  unless out =~ /IMAGE\s+(ami[-]\S+)/
    raise Exception.new("ERROR when creating ami: " + out)
  else
    sleep 5
    ami_id = $1
    `ec2-create-tags #{ami_id} --tag Name=#{name}`
    [ami_id, name]
  end  
end

def create_launch_config(ami_id, ami_name)
  system("as-create-launch-config #{ami_name} --image-id #{ami_id} --instance-type #{Gekko::Config::INSTANCE_TYPE} --group #{Gekko::Config::GROUP}")
end

def wait_available_ami(ami_id)
  while true
    # pooling until ready
    out = `ec2-describe-images #{ami_id} --show-empty-fields 2>&1`
    lines = out.split(/\r?\n/)

    if !lines || lines.length == 0 || lines[0] !~ /IMAGE\s+/
      status = "unknown"
    else
      elems = lines[0].split(/\s+/)
      status = elems[4]
    end

    if status != 'available'
      puts "Waiting on AMI (#{ami_id}: #{status})"
      sleep 5
    else
      break
    end
  end
end

def list_available_images
  out = `ec2-describe-images -F "name=gekko-*"`
  list = out.scan(/IMAGE\s+(ami[-]\w+)\s+\w+[\/](gekko[-]\d{8}[-]\d{6})/).map{|x| x.reverse}.flatten
  Hash[*list]
end

def list_available_scaling_groups
  out = `as-describe-auto-scaling-groups`
  raise Exception.new("ERROR: " + out) unless $?.exitstatus == 0

  matches = out.scan(/AUTO[-]SCALING[-]GROUP\s+(gekko[-]\d{8}[-]\d{6})\s+/)
  matches.map{|x| x[0]}
end

def check_launch_configuration(name)
  out = `as-describe-launch-configs #{name} 2>&1`
  if out !~ /LAUNCH[-]CONFIG\s+gekko-\d{8}-\d{8}/
    true
  else
    false
  end
end

def update_scaling_group(name, min, max, capacity)
  command = "as-update-auto-scaling-group #{name} --min-size #{min} --max-size #{max} --desired-capacity #{capacity}"
  puts "\n" + command
  raise Exception.new("Something wrong happened") unless system(command)
end

def get_scaling_group_instances(name)
  out = `as-describe-auto-scaling-groups #{name} 2>&1`
  raise Exception.new(out) unless $?.exitstatus == 0

  match = out.scan(/INSTANCE\s+(i[-]\w+)/)
  ids = match.map{|x| x[0]}

  out = `ec2-describe-instances #{ids.join(" ")} --show-empty-fields 2>&1`
  raise Exception.new(out) unless $?.exitstatus == 0
  
  match = out.scan(/INSTANCE\s+(i[-]\w+)\s+\S+\s+(ec2\S+[.com])\s+\S+\s+(\S+)/m)
  Hash[*match.map{|x| [x[0], {:host => x[1], :status => x[2]}]}.flatten]
end
