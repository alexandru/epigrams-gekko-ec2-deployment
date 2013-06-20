require 'ostruct'
require_relative "lib/base"

module Gekko::Config
  # for everything, including amis, auto-scaling configs, auto-scaling
  # groups
  NAME_PREFIX = "gekko"

  # name of load balancer targeted
  PRODUCTION_LB = "gekko"

  # security group
  GROUP = "Gekko"

  # DEFAULT_AMI = "ami-1ebb2077" # Ubuntu 12.04 LTS, AMD64
  DEFAULT_AMI = "ami-1cbb2075" # Ubuntu 12.04 LTS, i386

  # the instances we work with
  # INSTANCE_TYPE = "c1.xlarge"
  INSTANCE_TYPE = "c1.medium"

  AVAILABILITY_ZONES = ["us-east-1c"]

  # Number of instances to add on a scale up operation
  SCALE_UP_ADJUSTMENT = 4
  
  # Time (in seconds) between a successful Auto Scaling activity and
  # succeeding scaling activity.
  SCALE_UP_COOLDOWN = 10 * 60

  # Number of instances to add on a scale down operation
  SCALE_DOWN_ADJUSTMENT = -1
  
  # Time (in seconds) between a successful Auto Scaling activity and
  # succeeding scaling activity.
  SCALE_DOWN_COOLDOWN = 5 * 60

  # The period after an instance is launched. During this period, any health
  # check failure of that instance is ignored.
  SCALE_GRACE_PERIOD = 60 * 5

  AUTO_SCALE_POLICY = [
    OpenStruct.new(
     :suffix => "critical-latency-levels",
     :alarm_action => :scale_up,
     :operator => "GreaterThanThreshold",
     :evaluation_periods => 1,
     :namespace => "AWS/ELB",
     :metric_name => "Latency",
     :statistic => "Average",
     :period_secs => 60, # 60 secs
     :threshold => "0.02",
     :dimensions => "LoadBalancerName=#{PRODUCTION_LB}"
    ),
    OpenStruct.new(
     :suffix => "moderate-latency-levels",
     :ok_action => :scale_down,
     :operator => "GreaterThanThreshold",
     :evaluation_periods => 1,
     :namespace => "AWS/ELB",
     :metric_name => "Latency",
     :statistic => "Average",
     :period_secs => 60 * 60, # 60 minutes
     :threshold => "0.005",
     :dimensions => "LoadBalancerName=#{PRODUCTION_LB}"
    )
  ]
end
