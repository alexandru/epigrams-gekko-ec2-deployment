require_relative "../config"
require_relative "utils"

module Commands
  def self.verify_environment
    report_error(parser, "Environment variable AWS_ACCESS_KEY is not set") unless ENV['AWS_ACCESS_KEY']
    report_error(parser, "Environment variable AWS_SECRET_KEY is not set") unless ENV['AWS_SECRET_KEY']
    report_error(parser, "Environment variable AWS_CREDENTIAL_FILE is not set") unless ENV['AWS_CREDENTIAL_FILE']
  end

  def self.create_snapshot(keypair, identity, source_ami_id)
    self.verify_environment
    Dir.chdir(File.dirname(__FILE__))

    puts "Creating instance ..."
    instance_id = create_instances(keypair, 1, Gekko::Config::NAME_PREFIX, source_ami_id)[0]
    puts "Created instance ID: #{instance_id}"

    ami_id = nil

    begin
      host = wait_running(instance_id)

      fab_cmd = "fab -n 10 -u ubuntu -i #{identity} -H #{host} provision"
      puts "Provisioning instance ... #{fab_cmd}"
      raise Exception.new("Something wrong happened (when running fab)") unless system(fab_cmd)

      puts "Create AMI ..."

      ami_info = create_ami(instance_id, Gekko::Config::NAME_PREFIX)
      ami_id, ami_name = ami_info[0], ami_info[1]

      wait_available_ami(ami_id)
      create_launch_config(ami_id, ami_name)

      ami_name
    rescue
      system("ec2-deregister #{ami_id}") if ami_id
      raise
    ensure
      system("ec2-terminate-instances #{instance_id}")
    end
  end

  def self.update_deployed_snapshot(snapshot, min_size, max_size, desired_capacity)
    command = "
      as-update-auto-scaling-group #{snapshot} \\
         --min-size #{min_size} \\
         --max-size #{max_size} \\
         --desired-capacity #{desired_capacity} \\
         --health-check-type #{Gekko::Config::HEALTH_CHECK_TYPE} \\
         --grace-period #{Gekko::Config::GRACE_PERIOD}
    ".split(/\r?\n/).map{|x| x[6..-1]}.join("\n")

    puts command
    result = system(command)

    raise Exception.new("Something wrong happened (updating auto-scaling group)") unless result

    command = "
      as-put-scaling-policy #{snapshot}-scale-up \\
        --auto-scaling-group #{snapshot} \\
        --adjustment=#{Gekko::Config::SCALE_UP_ADJUSTMENT} \\
        --type ChangeInCapacity \\
        --cooldown #{Gekko::Config::SCALE_UP_COOLDOWN} 2>&1
    ".split(/\r?\n/).map{|x| x[6..-1]}.join("\n")

    puts command
    scale_up_policy = `#{command}`.strip

    raise Exception.new("ERROR: " + scale_up_policy) unless $?.exitstatus == 0
    puts "\nCreated #{snapshot}-scale-up scaling policy ID: #{scale_up_policy}"
    
    command = "
      as-put-scaling-policy #{snapshot}-scale-down \\
        --auto-scaling-group #{snapshot} \\
        --adjustment=#{Gekko::Config::SCALE_DOWN_ADJUSTMENT} \\
        --type ChangeInCapacity \\
        --cooldown #{Gekko::Config::SCALE_DOWN_COOLDOWN} 2>&1
    ".split(/\r?\n/).map{|x| x[6..-1]}.join("\n")

    puts command
    scale_down_policy = `#{command}`.strip

    raise Exception.new("ERROR: " + scale_down_policy) unless $?.exitstatus == 0
    puts "\nCreated #{snapshot}-scale-down scaling policy ID: #{scale_down_policy}"

    Gekko::Config::AUTO_SCALE_POLICY.each do |m|
      if m.ok_action
        action_type = "ok"
        action_value = m.ok_action
      else
        action_type = "alarm"
        action_value = m.alarm_action
      end

      if action_value == :scale_down
        action_value = scale_down_policy
      else
        action_value = scale_up_policy
      end

      command = "
        mon-put-metric-alarm #{snapshot}-#{m.suffix} \\
          --comparison-operator #{m.operator} \\
          --evaluation-periods #{m.evaluation_periods} \\
          --metric-name #{m.metric_name} \\
          --namespace \"#{m.namespace}\" \\
          --period \"#{m.period_secs}\" \\
          --statistic \"#{m.statistic}\" \\
          --threshold #{m.threshold} \\
          --#{action_type}-actions \"#{action_value}\" \\
          --dimensions \"#{m.dimensions}\"
      ".split(/\r?\n/).map{|x| x[8..-1]}.join("\n")

      puts "\n" + command
      result = system(command)
      raise Exception.new("Something wrong happened (creating metric alarm)") unless result
    end
  end

  def self.deploy_snapshot(snapshot, min_size, max_size, desired_capacity)
    zones = Gekko::Config::AVAILABILITY_ZONES.join(",")
    lb_name = Gekko::Config::PRODUCTION_LB

    command = "
      as-create-auto-scaling-group #{snapshot} \\
         --availability-zones #{zones} \\
         --launch-configuration #{snapshot} \\
         --min-size 0 \\
         --max-size 1 \\
         --desired-capacity 0 \\
         --load-balancers #{lb_name} \\
         --health-check-type #{Gekko::Config::HEALTH_CHECK_TYPE} \\
         --grace-period #{Gekko::Config::GRACE_PERIOD} \\
         --tag \"k=Name,v=#{snapshot},p=true\"
    ".split(/\r?\n/).map{|x| x[6..-1]}.join("\n")

    puts command
    result = system(command)

    raise Exception.new("Something wrong happened (creating auto-scaling group)") unless result

    begin
      command = "
        as-put-scaling-policy #{snapshot}-scale-up \\
          --auto-scaling-group #{snapshot} \\
          --adjustment=#{Gekko::Config::SCALE_UP_ADJUSTMENT} \\
          --type ChangeInCapacity \\
          --cooldown #{Gekko::Config::SCALE_UP_COOLDOWN} 2>&1
      ".split(/\r?\n/).map{|x| x[8..-1]}.join("\n")

      puts command
      scale_up_policy = `#{command}`.strip

      raise Exception.new("ERROR: " + scale_up_policy) unless $?.exitstatus == 0
      puts "\nCreated #{snapshot}-scale-up scaling policy ID: #{scale_up_policy}"

      command = "
        as-put-scaling-policy #{snapshot}-scale-down \\
          --auto-scaling-group #{snapshot} \\
          --adjustment=#{Gekko::Config::SCALE_DOWN_ADJUSTMENT} \\
          --type ChangeInCapacity \\
          --cooldown #{Gekko::Config::SCALE_DOWN_COOLDOWN} 2>&1
      ".split(/\r?\n/).map{|x| x[8..-1]}.join("\n")

      puts command
      scale_down_policy = `#{command}`.strip

      raise Exception.new("ERROR: " + scale_down_policy) unless $?.exitstatus == 0
      puts "\nCreated #{snapshot}-scale-down scaling policy ID: #{scale_down_policy}"

      Gekko::Config::AUTO_SCALE_POLICY.each do |m|
        if m.ok_action
          action_type = "ok"
          action_value = m.ok_action
        else
          action_type = "alarm"
          action_value = m.alarm_action
        end

        if action_value == :scale_down
          action_value = scale_down_policy
        else
          action_value = scale_up_policy
        end

        command = "
          mon-put-metric-alarm #{snapshot}-#{m.suffix} \\
            --comparison-operator #{m.operator} \\
            --evaluation-periods #{m.evaluation_periods} \\
            --metric-name #{m.metric_name} \\
            --namespace \"#{m.namespace}\" \\
            --period \"#{m.period_secs}\" \\
            --statistic \"#{m.statistic}\" \\
            --threshold #{m.threshold} \\
            --#{action_type}-actions \"#{action_value}\" \\
            --dimensions \"#{m.dimensions}\"
        ".split(/\r?\n/).map{|x| x[10..-1]}.join("\n")

        puts "\n" + command
        result = system(command)
        raise Exception.new("Something wrong happened (creating metric alarm)") unless result
      end

    rescue
      $stderr.puts "\nDeleting auto scaling group due to error"
      sleep(3)
      command = "as-delete-auto-scaling-group #{snapshot} --force-delete --force"
      $stderr.puts command
      system(command)
      raise
    else
      command = "as-update-auto-scaling-group #{snapshot} --min-size #{min_size} --max-size #{max_size} --desired-capacity #{desired_capacity}"
      puts "\n" + command
      raise Exception.new("Something wrong happened (updating auto-scaling group)") unless system(command)
    end
  end
end
