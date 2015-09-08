# -*- mode: ruby -*-

require "yaml"

# Load up our config files
# First, load 'config/default.yaml'
CONF = YAML.load(File.open("config/default.yaml", File::RDONLY).read)

# Next, load local overrides from 'config/local.yaml'
# If it doesn't exist, no worries. We'll just use the defaults
if File.exists?("config/local.yaml")
  CONF.merge!(YAML.load(File.open("config/local.yaml", File::RDONLY).read))
end

# At this point, all our configs can be referenced as CONF['key'], e.g. CONF['vb_name']

####################################
# Currently, we require Vagrant 1.6.0 or above.
Vagrant.require_version ">= 1.6.0"

# Actual Vagrant configs
Vagrant.configure("2") do |config|

    config.vm.box = CONF['vagrant_box']

    # The url from where the 'config.vm.box' box will be fetched if it
    # doesn't already exist on the user's system.
    if CONF['vagrant_box_url']
        config.vm.box_url = CONF['vagrant_box_url']
    end

    # define this box so Vagrant doesn't call it "default"
    config.vm.define "pmltq-vagrant"

    # Hostname for virtual machine
    config.vm.hostname = "pmltq.vagrant.dev"

    #-----------------------------
    # Network Settings
    #-----------------------------
    # configure a private network and set this guest's IP to 192.168.50.2
    config.vm.network "private_network", ip: CONF['ip_address']

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. 
    config.vm.network :forwarded_port, guest: 80, host: CONF['port'],
      auto_correct: true

    # If a port collision occurs (i.e. port 8080 on local machine is in use),
    # then tell Vagrant to use the next available port between 8081 and 8100
    config.vm.usable_port_range = 9990..9999

    # BEGIN Landrush (https://github.com/phinze/landrush) configuration
    # This section will only be triggered if you have installed "landrush"
    #     vagrant plugin install landrush
    if Vagrant.has_plugin?('landrush')
        config.landrush.enable
        # let's use the Google free DNS
        config.landrush.upstream '8.8.8.8'
        config.landrush.guest_redirect_dns = false
    end
    # END Landrush configuration

    #------------------------------
    # Caching Settings (if enabled)
    #------------------------------
    # BEGIN Vagrant-Cachier (https://github.com/fgrehm/vagrant-cachier) configuration
    # This section will only be triggered if you have installed "vagrant-cachier"
    #     vagrant plugin install vagrant-cachier
    if Vagrant.has_plugin?('vagrant-cachier')
       # Use a vagrant-cachier cache if one is detected
       config.cache.auto_detect = true

       # set vagrant-cachier scope to :box, so other projects that share the
       # vagrant box will be able to used the same cached files
       config.cache.scope = :box

       # and lets specifically use the apt cache (note, this is a Debian-ism)
       config.cache.enable :apt
    end
    # END Vagrant-Cachier configuration

    #-----------------------------
    # Basic System Customizations
    #-----------------------------
    # Check our system locale -- make sure it is set to UTF-8
    # This also means we need to run 'dpkg-reconfigure' to avoid "unable to re-open stdin" errors (see http://serverfault.com/a/500778)
    # For now, we have a hardcoded locale of "en_US.UTF-8"
    locale = "en_US.UTF-8"
    config.vm.provision :shell, :inline => "echo 'Setting locale to UTF-8 (#{locale})...' && locale | grep 'LANG=#{locale}' > /dev/null || update-locale --reset LANG=#{locale} && dpkg-reconfigure locales"

    # Turn off annoying console bells/beeps in Ubuntu (only if not already turned off in /etc/inputrc)
    config.vm.provision :shell, :inline => "echo 'Turning off console beeps...' && grep '^set bell-style none' /etc/inputrc || echo 'set bell-style none' >> /etc/inputrc"

    #------------------------
    # Enable SSH Forwarding
    #------------------------
    # Turn on SSH forwarding (so that 'vagrant ssh' has access to your local SSH keys, and you can use your local SSH keys to access GitHub, etc.)
    config.ssh.forward_agent = true

    # Prevent annoying "stdin: is not a tty" errors from displaying during 'vagrant up'
    # See also https://github.com/mitchellh/vagrant/issues/1673#issuecomment-28288042
    config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

    config.vm.provision :shell, :inline => "sudo apt-get update"

    # Shell script to initialize latest Puppet on VM & also install librarian-puppet (which manages our third party puppet modules)
    # This has to be done before the puppet provisioning so that the modules are available when puppet tries to parse its manifests.
    config.vm.provision :shell, :path => "projects/puppet-bootstrap.sh"

    # Copy our 'hiera.yaml' file over to the global Puppet directory (/etc/puppet) on VM
    # This lets us run 'puppet apply' manually on the VM for any minor updates or tests
    config.vm.provision :shell, :inline => "cp /vagrant/projects/hiera.yaml /etc/puppet"
   
    # display the local.yaml file, if it exists, to give us a chance to back out
    # before waiting for this vagrant up to complete
    if File.exists?("config/local.yaml")
        config.vm.provision :shell, :inline => "echo '   > > > using the following local.yaml data, if this is not correct, control-c now...'"
        config.vm.provision :shell, :inline => "echo '---BEGIN local.yaml ---' && cat /vagrant/config/local.yaml && echo '--- END local.yaml -----'"
    end

    # Call our Puppet initialization script
    config.vm.provision :shell, :inline => "echo '   > > > Beginning Puppet provisioning, this may take a while...'"

    # Actually run Puppet to setup the server
    config.vm.provision :puppet do |puppet|
        puppet.manifests_path = "projects"
        puppet.manifest_file = "puppet-setup.pp"
        puppet.options = "--verbose"
    end

    # Load any local customizations from the "local-bootstrap.sh" script (if it exists)
    # Check out the "config/local-bootstrap.sh.example" for examples
    if File.exists?("config/local-bootstrap.sh")
        config.vm.provision :shell, :inline => "echo '   > > > running config/local_bootstrap.sh'"
        config.vm.provision :shell, :path => "config/local-bootstrap.sh"
    end

    # For IDE support
    if CONF['sync_src_to_host'] == true
        config.vm.synced_folder "projects", "/home/vagrant/projects"
    end

    config.vm.provider :virtualbox do |vb|
        # Boot into GUI mode (login: vagrant, pwd: vagrant). Useful for debugging boot issues, etc.
        vb.gui = CONF['vm_gui_mode']

        # Name of the VM created in VirtualBox (Also the name of the subfolder in ~/VirtualBox VMs/ where this VM is kept)
        vb.name = CONF['vm_name']

        # Let VirtualBox know this is Ubuntu
        vb.customize ["modifyvm", :id, "--ostype", 'Ubuntu']

        # Use VBoxManage to provide Virtual Machine with extra memory (default is only 300MB)
        vb.customize ["modifyvm", :id, "--memory", CONF['vm_memory']]

        if CONF['vb_max_cpu']
          # Use VBoxManage to ensure Virtual Machine only has access to a percentage of host CPU
          vb.customize ["modifyvm", :id, "--cpuexecutioncap", CONF['vm_max_cpu']]
        end

        # Use VBoxManage to have the Virtual Machine use the Host's DNS resolver
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

        # This allows symlinks to be created within the /vagrant root directory,
        # which is something librarian-puppet needs to be able to do. This might
        # be enabled by default depending on what version of VirtualBox is used.
        # Borrowed from https://github.com/purple52/librarian-puppet-vagrant/
        vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
        
    end
    
    config.vm.provision "shell", path: "./projects/setup.sample_treebank.sh", privileged: false

    # Message to display to user after 'vagrant up' completes
    config.vm.post_up_message = "Setup of 'pmltq-vagrant' is now COMPLETE! PML-TQ should now be available at:\n\nhttp://localhost:#{CONF['port']}/\n\nYou can also SSH into the new VM via 'vagrant ssh'"
end