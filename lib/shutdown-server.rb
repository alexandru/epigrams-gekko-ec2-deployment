#!/usr/bin/env ruby

def running_pid
  process_list = `ps aux | grep play.core.server.NettyServe[r]`.strip
  if process_list && process_list != ""
    pid = process_list.split(/\s+/)[1]
  else
    pid = nil
  end
end

retries = 0
while pid = running_pid
  retries += 1
  if retries == 180
    puts "Process still active, sending SIGKILL"
    `kill -9 #{pid}`
  else
    puts "Process active, sending SIGTERM, sleeping"
    `kill #{pid}`
    sleep(3)
  end
end
