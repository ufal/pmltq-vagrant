#!/usr/bin/env bash
#
# This bootstraps Puppet & Librarian-Puppet on Ubuntu 12.04 LTS or 14.04LTS.
# Based on the script at: https://github.com/hashicorp/puppet-bootstrap/
# 
# However, we've updated it to also install and configure librarian-puppet
# https://github.com/rodjek/librarian-puppet  
# We use librarian-puppet to auto-install 3rd party Puppet modules.
#
echo "======================================="
echo "STARTING puppet-bootstrap"
gstart=`date +%s`

set -e

# Puppet directory (this is where we want Puppet to be installed & all its main modules)
PUPPET_DIR=/etc/puppet/
PROJECTS_DIR=/home/vagrant/projects

# Load up the release information
. /etc/lsb-release

REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"

# Version of librarian-puppet to install
LIBRARIAN_PUPPET_VERSION=2.2.1

#--------------------------------------------------------------------
# NO TUNABLES BELOW THIS POINT
#--------------------------------------------------------------------
if [ "$(id -u)" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if which puppet > /dev/null 2>&1 && apt-cache policy | grep --quiet apt.puppetlabs.com; then
  echo "Puppet is already installed."
  exit 0
fi

# COMMENTED OUT, as we already ran apt-get update prior to this script
# Do the initial apt-get update
#echo "Initial apt-get update..."
#apt-get update >/dev/null

# Install wget if we have to (some older Ubuntu versions)
echo "Installing wget..."
apt-get install -y wget >/dev/null

# Install the PuppetLabs repo
echo "Configuring PuppetLabs repo..."
repo_deb_path=$(mktemp)
wget --output-document="${repo_deb_path}" "${REPO_DEB_URL}" 2>/dev/null
dpkg -i "${repo_deb_path}" >/dev/null
apt-get update >/dev/null

# Install Puppet
echo "Installing Puppet..."
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install puppet >/dev/null
echo "Puppet installed!"

echo "Installing RubyGems..."
if [ $DISTRIB_CODENAME != "trusty" ]; then
  apt-get install -y rubygems >/dev/null
fi
gem install --no-ri --no-rdoc rubygems-update
update_rubygems >/dev/null

# Install our custom Puppet config file f
cp $PROJECTS_DIR/puppet.conf $PUPPET_DIR

### Start librarian-puppet installation & initialization

# Install Git
echo "Installing Git..."
apt-get install -y git >/dev/null
echo "Git installed!"

# Ensure Puppet directory exists & the 'librarian-puppet' Puppetfile is copied there.
if [ ! -d "$PUPPET_DIR" ]; then
  mkdir -p $PUPPET_DIR
fi
# Install our custom librarian-puppet config file
cp $PROJECTS_DIR/Puppetfile $PUPPET_DIR

# Install 'librarian-puppet' and all third-party modules configured in Puppetfile
if [ "$(gem search -i librarian-puppet)" = "false" ]; then
  echo "Installing librarian-puppet..."
  apt-get install ruby1.9.1-dev
  gem install --no-ri --no-rdoc librarian-puppet --version $LIBRARIAN_PUPPET_VERSION >/dev/null
  echo "librarian-puppet installed!"
  echo "Installing third-party Puppet modules (via librarian-puppet)..."
  cd $PUPPET_DIR && librarian-puppet install --clean
else
  echo "Updating third-party Puppet modules (via librarian-puppet)..."
  cd $PUPPET_DIR && librarian-puppet update
fi

gend=`date +%s`
echo "ENDING took $((end-start)) seconds"
echo "======================================="