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

  # the instances we work with
  INSTANCE_TYPE = "c1.medium"

  AVAILABILITY_ZONES = ["us-east-1c"]

  # Number of instances to add on a scale up operation
  SCALE_UP_ADJUSTMENT = 1
  
  # Time (in seconds) between a successful Auto Scaling activity and
  # succeeding scaling activity.
  SCALE_UP_COOLDOWN = 2 * 60 # 2 minutes  

  # Number of instances to add on a scale down operation
  SCALE_DOWN_ADJUSTMENT = -1
  
  # Time (in seconds) between a successful Auto Scaling activity and
  # succeeding scaling activity.
  SCALE_DOWN_COOLDOWN = 5 * 60 # 5 minutes  

  AUTO_SCALE_POLICY = [
    OpenStruct.new(
     :suffix => "critical-latency-levels",
     :alarm_action => :scale_up,
     :operator => "GreaterThanThreshold",
     :evaluation_periods => 1,
     :namespace => "AWS/ELB",
     :metric_name => "Latency",
     :statistic => "Average",
     :period_secs => 3 * 60, # 3 minutes
     :threshold => "0.3",
     :dimensions => "LoadBalancerName=#{PRODUCTION_LB}"
    ),
    OpenStruct.new(
     :suffix => "high-latency-levels",
     :ok_action => :scale_down,
     :operator => "GreaterThanThreshold",
     :evaluation_periods => 1,
     :namespace => "AWS/ELB",
     :metric_name => "Latency",
     :statistic => "Average",
     :period_secs => 30 * 60, # 30 minutes
     :threshold => "0.2",
     :dimensions => "LoadBalancerName=#{PRODUCTION_LB}"
    )
  ]
end