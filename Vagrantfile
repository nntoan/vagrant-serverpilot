# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Path to settings file
SETTINGS_FILE = "settings.yml"

# Load the settings file with fucking absolute path for greater good
settings = YAML.load_file(File.join(File.dirname(__FILE__), SETTINGS_FILE))

# Function to check whether VM was already provisioned
def provisioned?(vm_name='default', provider='virtualbox')
  File.exist?(".vagrant/machines/#{vm_name}/#{provider}/action_provision")
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  begin
    config.vm.box = settings['vagrant']['box'] ||= 'ubuntu/xenial64'
    if settings['vagrant']['box_url'] != nil
      config.vm.box_url = settings['vagrant']['box_url']
    end

    # After provisioned, use 'serverpilot' user instead
    #config.ssh.username = settings['vagrant']['ssh']['username'] if provisioned?

    # Configure default synced folder (disable by default) - WIP
    config.vm.synced_folder '.', '/vagrant', disabled: true

    config.vm.provider "virtualbox" do |vbox, override|
      # IPs and ports handler
      settings['network']['ports'].each do |port|
        override.vm.network "forwarded_port", guest: port['guest'], host: port['host']
      end
      if settings['network']['private']['enabled'] == true
        override.vm.network "private_network", ip: settings['network']['private']['ip_addr']
      end
      if settings['network']['public']['enabled'] == true
        override.vm.network "public_network", bridge: settings['network']['public']['bridge'], ip: settings['network']['public']['ip_addr']
      end

      # Hostname/Name of machine
      #vbox.hostname = settings['vbox']['hostname'] ||= nil
      vbox.name = settings['vbox']['name'] ||= 'vagrant-serverpilot'
      # To debug only
      vbox.gui = settings['vbox']['debug'] ||= false

      # Customize the amount of memory & cpus on the VM
      if settings['vbox']['res_auto'] == true
        host = RbConfig::CONFIG['host_os']
        if host =~ /darwin/
          cpus = `sysctl -n hw.ncpu`.to_i
          mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4
        elsif host =~ /linux/
          cpus = `nproc`.to_i
          mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4
        else
          cpus = settings['vbox']['vcpu'] ||= 2
          mem = settings['vbox']['ram'] ||= 1536
        end
      else
        cpus = settings['vbox']['vcpu'] ||= 1
        mem = settings['vbox']['ram'] ||= 1024
      end
      vbox.customize ["modifyvm", :id, "--memory", mem]
      vbox.customize ["modifyvm", :id, "--cpus", cpus]
    end

    # There is known bug of ubuntu xenial64 cloud-image, it's using password instead of private_key
    # Here is how we deal with it, for faster "vagrant up"
    config.vm.provision "shell", inline: <<-SHELL
       echo "ubuntu:ubuntu" | sudo chpasswd
    SHELL

    # If you are going to add more opts, ensure " \
    # after the last opt, e.g -x #{settings['hello']['world']}" \
    # and the args must be 1 letter, because we're using getopts
    # (optional): if you don't want to see a lot of command output
    # while provisioning, change mode to "simple" instead of "verbose"
    config.vm.provision "shell", path: "scripts/bootstrap.#{settings['vagrant']['provision']['mode']}.sh",
    args: "-i #{settings['serverpilot']['server_id']} \
           -k #{settings['serverpilot']['api_key']} \
           -s #{settings['serverpilot']['sudo']} \
           -p #{settings['serverpilot']['php']} \
           -b #{settings['shell']['ohmybash']} \
           -z #{settings['shell']['ohmyzsh']}" \
  end
end
