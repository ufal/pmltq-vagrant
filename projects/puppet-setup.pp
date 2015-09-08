# Setup Puppet Script
#

# =========================
#

# Global default to requiring all packages be installed & apt-update to be run first
Package {
  ensure => latest,                # requires latest version of each package to be installed
  require => Exec['apt-get-update'],
}

# Global default path settings for all 'exec' commands
Exec {
  path => '/usr/bin:/usr/sbin/:/bin:/sbin:/usr/local/bin:/usr/local/sbin',
}

# Add the 'partner' repositry to apt
# NOTE: $lsbdistcodename is a 'fact' which represents the ubuntu codename (e.g. 'precise')
file { 'partner.list':
  path    => '/etc/apt/sources.list.d/partner.list',
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  content => "deb http://archive.canonical.com/ubuntu ${lsbdistcodename} partner
              deb-src http://archive.canonical.com/ubuntu ${lsbdistcodename} partner",
  notify  => Exec['apt-get-update'],
}

# Run apt-get update before installing anything
exec {'apt-get-update':
  command => '/usr/bin/apt-get update',
  refreshonly => true, # only run if notified
}

# =========================
# Basics
#

file_line { 'env_editor':
   path => '/home/vagrant/.bashrc',
   line => 'export EDITOR=nano;',
}

$packages = [
    'build-essential',
    'curl',
    'git-core',
    'htop',
    'libfontconfig1-dev',
    'libpng12-dev',
    'libx11-dev',
    'libxft-dev',
    'libxml2',
    'libxml2-dev',
    'libxml2-utils',
    'postgresql-server-dev-all',
    'subversion',
    'unzip',
    'xvfb',
    'zlib1g-dev',
    'php5-cgi',
  ]

package { $packages:
  ensure  => 'installed',
}

class { 'timezone':
  region => 'Europe',
  locality => 'Prague',
}

# Database

include postgresql::server

postgresql::server::role { 'pmltq':
  password_hash => postgresql_password('pmltq', 'pmltq'),
  createdb => true
}

postgresql::server::db { 'pmltq':
  user     => 'pmltq',
  password => postgresql_password('pmltq', 'pmltq'),
  require => Postgresql::Server::Role['pmltq']
}

postgresql::server::database_grant { 'pmltq_db_access':
  privilege => 'ALL',
  db        => 'pmltq',
  role      => 'pmltq',
  require => Postgresql::Server::Db['pmltq']
}

# Perl

perlbrew { '/home/vagrant':
  owner  => 'vagrant',
  group  => 'vagrant',
  bashrc => true,
  require => Package[$packages]
}

perlbrew::perl { 'perl-pmltq':
  target => '/home/vagrant',
  version => 'perl-5.12.5',
}

$cpan_packages = [
  'Algorithm::Diff',
  'Carp::Always',
  'DBD::Pg',
  'DBI',
  'Graph',
  'Graph::ChuLiuEdmonds',
  'HTML::TokeParser',
  'HTTP::Request',
  'HTTP::Request::AsCGI',
  'HTTP::Server::Simple::CGI',
  'IO::Scalar',
  'IO::Zlib',
  'JSON',
  'List::MoreUtils',
  'MIME::Types',
  'Net::HTTPServer',
  'Parse::RecDescent',
  'Readonly',
  'Sys::SigAction',
  'Tk',
  'Treex::Core',
  'Treex::PML',
  'UNIVERSAL::DOES',
  'XML::LibXML',
  'XML::Parser',
  'YAML',
]

perlbrew::cpanm { $cpan_packages:
  target => 'perl-pmltq',
}

# Tred

vcsrepo { '/opt/tred':
  ensure   => present,
  provider => svn,
  source   => 'svn://anonymous@svn.ms.mff.cuni.cz/TrEd/trunk/tred_refactored/',
}

file_line { 'env_tred':
   path => '/home/vagrant/.bashrc',
   line => 'if [ -d "/opt/tred" ]; then export PATH="/opt/tred:$PATH"; fi',
}

Archive {
  checksum => false,
  follow_redirects => true,
  timeout => 1000
}

archive { 'pmltq_engine':
  ensure => present,
  url    => 'http://euler.ms.mff.cuni.cz/static/pmltq.tar.gz',
  target => '/opt/pmltq',
}

archive { 'tred_extensions':
  ensure => present,
  url    => 'http://euler.ms.mff.cuni.cz/static/tred-extensions.tar.gz',
  target => '/opt/pmltq',
}

# Run apt-get update before installing anything
exec {'pmltq_chown':
  command => 'chown vagrant:vagrant -R /opt/pmltq',
  require => [
    Archive['tred_extensions'],
    Archive['pmltq_engine'],
    Vcsrepo['/opt/tred']
  ],
}

# Front page

class { 'php':
  service => 'nginx',
  package => 'php5-fpm',
  config_file => '/etc/php5/fpm/php.ini',
  config_dir => '/etc/php5/',
  require => Package[$packages],
}

php::mod { "json": }

class { 'nginx':
}

$www_root = '/opt/pmltq/engine/contrib/fronted_page'
$www_host = hiera('ip_address')

file_line { 'index_host':
  path => "$www_root/index.php",
  after => '// Setup:',
  line => "if(!defined('PMLTQ_HOST')) { define('PMLTQ_HOST', 'http://${www_host}'); }",
  require => [
    Archive['pmltq_engine'],
  ],
}

nginx::resource::vhost { 'localhost':
  ensure => present,
  listen_port => 80,
  www_root => $www_root,
  index_files => [ 'index.php' ],
  location_cfg_append   => {
    try_files => '$uri $uri/ =404'
  },
}

nginx::resource::location { "pmltq_root":
  ensure          => present,
  vhost           => 'localhost',
  www_root        => $www_root,
  location        => '~ \.php$',
  index_files     => ['index.php', 'index.html', 'index.htm'],
  proxy           => undef,
  fastcgi         => "unix:/var/run/php5-fpm.sock",
  fastcgi_script  => undef,
  location_cfg_append => {
    fastcgi_split_path_info => '^(.+\.php)(/.+)$',
    fastcgi_index => 'index.php',
    fastcgi_connect_timeout => '3m',
    fastcgi_read_timeout    => '3m',
    fastcgi_send_timeout    => '3m'
  }
}

