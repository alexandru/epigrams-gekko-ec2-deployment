require 'date'

def get_keypairs
  out = `ec2-describe-keypairs 2>&1`
  match = out.scan(/KEYPAIR\s+(\S+)/)  
  match.map{|x| x[0]}
end

def create_instances(keypair, nr, tag_name, ami_id=nil)
  ami_id ||= "ami-1cbb2075" # ubuntu 12.04 LTS

  ids = []
  (0...nr).each do |i|
    out = `ec2-run-instances #{ami_id} -k #{keypair} --monitor -n 1 -t c1.medium -g gekko --instance-initiated-shutdown-behavior stop 2>&1`
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
    ami_id = $1
    `ec2-create-tags #{ami_id} --tag Name=#{name}`
    [ami_id, name]
  end  
end

def create_launch_config(ami_id, ami_name)
  system("as-create-launch-config #{ami_name} --image-id #{ami_id} --instance-type c1.medium --group Gekko")
end

def wait_available_ami(ami_id)
  while true
    # pooling until ready
    out = `ec2-describe-images #{ami_id} --show-empty-fields 2>&1`
    lines = out.split(/\r?\n/)
    if !lines || lines.length == 0 || lines[0] !~ /IMAGE\s+/
      raise Exception.new("ERROR when waiting for ami: " + out)
    else
      elems = lines[0].split(/\s+/)
      if elems[4] != 'available'
        puts "Waiting on AMI (#{ami_id}: #{elems[4]})"
        sleep 3
      else
        break
      end
    end
  end
end

def list_available_images
  out = `ec2-describe-images -F "name=gekko-*"`
  out.scan(/IMAGE\s+(ami[-]\w+)\s+\w+[\/](gekko[-]\d{8}[-]\d{6})/).sort_by{|a,b| a[1] <=> b[1]}
end
