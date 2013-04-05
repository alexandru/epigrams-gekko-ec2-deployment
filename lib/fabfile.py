import os
from fabric.api import run
from fabric.operations import run, put


def ping():
    run("echo 'Instance is ready'")

def provision():
    project_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    # shutdown gekko, just in case it is already preset
    run("sudo service gekko shutdown || echo 'Gekko is not present'")
    
    # disable firewal
    run("sudo ufw disable")

    # creating user
    run("sudo useradd --create-home --shell \"/bin/bash\" --user-group \"gekko\" || echo ''")

    # installing key
    put(os.path.join(project_dir, "key", "id_rsa"), "/tmp/")
    put(os.path.join(project_dir, "key", "id_rsa.pub"), "/tmp/")
    put(os.path.join(project_dir, "key", "known_hosts"), "/tmp/")

    run("sudo mkdir -p /home/gekko/.ssh")
    run("sudo mv /tmp/id_rsa* /home/gekko/.ssh/")
    run("sudo mv /tmp/known_hosts /home/gekko/.ssh/")
    run("sudo chmod -R go-rwx /home/gekko/.ssh")
    run("sudo chown -R gekko:gekko /home/gekko/.ssh")

    # installing required software packages
    run("cd /tmp && rm -rf repo-deb-build-0002.deb && wget http://apt.typesafe.com/repo-deb-build-0002.deb")
    run("sudo dpkg -i /tmp/repo-deb-build-0002.deb")

    run("sudo apt-add-repository -y ppa:webupd8team/java")
    run("sudo aptitude update && sudo aptitude -y upgrade")
    run("sudo echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections")
    run("sudo aptitude -y install oracle-java7-installer git typesafe-stack ruby1.9.3 htop iotop lsof sysstat")
    run("sudo update-java-alternatives -s java-7-oracle || echo 'OK'")
    run("cd /tmp/ && rm -rf sbt-launch.jar && wget http://typesafe.artifactoryonline.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/0.12.2/sbt-launch.jar")
    run("sudo mkdir -p /home/gekko/.sbt/.lib/0.12.2/ && sudo mv /tmp/sbt-launch.jar /home/gekko/.sbt/.lib/0.12.2/")
    run("sudo chown -R gekko:gekko /home/gekko/.sbt")
    run("sudo mkdir -p /home/gekko/bin")

    # installing system-wide configuration settings
    put(os.path.join(project_dir, "config", "profile"), "/home/gekko/.gekko_profile", use_sudo=True)
    put(os.path.join(project_dir, "config", "refresh-codebase"), "/home/gekko/bin/refresh-codebase", use_sudo=True)
    put(os.path.join(project_dir, "config", "gekko-run-server"), "/home/gekko/bin/gekko-run-server", use_sudo=True)

    # for freaking open file handle limits, an ongoing nightmare
    put(os.path.join(project_dir, "config", "security-limits.conf"), "/etc/security/limits.conf", use_sudo=True)
    put(os.path.join(project_dir, "config", "sysctl.conf"), "/etc/sysctl.conf", use_sudo=True)
    put(os.path.join(project_dir, "config", "common-session"), "/etc/pam.d/common-session", use_sudo=True)
    put(os.path.join(project_dir, "config", "common-session-noninteractive"), "/etc/pam.d/common-session-noninteractive", use_sudo=True)
    run("sudo -i sysctl -p")

    # for using the ephemeral /mnt
    put(os.path.join(project_dir, "config", "fstab"), "/etc/fstab", use_sudo=True)
    put(os.path.join(project_dir, "config", "rc.local"), "/etc/rc.local", use_sudo=True)
    run("sudo chmod +x /etc/rc.local")

    # for startup of the project on boot
    put(os.path.join(project_dir, "config", "gekko-upstart.conf"), "/etc/init/gekko.conf", use_sudo=True)

    # preparing project files
    run("sudo chmod +x /home/gekko/bin/gekko-run-server")
    run("sudo chmod 600 /home/gekko/.gekko_profile")
    run("sudo chown gekko:gekko /home/gekko/.gekko_profile")
    run("sudo chmod +x /home/gekko/bin/refresh-codebase")
    run("sudo chown -R gekko:gekko /home/gekko/")    

    # cloning repository and building it
    run("sudo -i -u gekko /home/gekko/bin/refresh-codebase")


