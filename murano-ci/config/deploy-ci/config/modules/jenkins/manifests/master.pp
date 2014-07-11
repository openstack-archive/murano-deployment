# == Class: jenkins::master
#
class jenkins::master(
  $logo = '',
  $vhost_name = $::fqdn,
  $serveradmin = "webmaster@${::fqdn}",
  $ssl_cert_file = '',
  $ssl_key_file = '',
  $ssl_chain_file = '',
  $ssl_cert_file_contents = '', # If left empty puppet will not create file.
  $ssl_key_file_contents = '', # If left empty puppet will not create file.
  $ssl_chain_file_contents = '', # If left empty puppet will not create file.
  $jenkins_ssh_private_key = '',
  $jenkins_ssh_public_key = '',
) {
  include pip
  include apt
#  include apache

  package { 'openjdk-7-jre-headless':
    ensure => present,
  }

  package { 'openjdk-6-jre-headless':
    ensure  => purged,
    require => Package['openjdk-7-jre-headless'],
  }

  #This key is at http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key
  apt::key { 'jenkins':
    key        => 'D50582E6',
    key_source => 'http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key',
    require    => Package['wget'],
  }

  apt::source { 'jenkins':
    location    => 'http://pkg.jenkins-ci.org/debian',
    release     => 'binary/',
    repos       => '',
    require     => [
      Apt::Key['jenkins'],
      Package['openjdk-7-jre-headless'],
    ],
    include_src => false,
  }

#  apache::vhost { $vhost_name:
#    port     => 443,
#    docroot  => 'MEANINGLESS ARGUMENT',
#    priority => '50',
#    template => 'jenkins/jenkins.vhost.erb',
#    ssl      => true,
#  }
#  a2mod { 'rewrite':
#    ensure => present,
#  }
#  a2mod { 'proxy':
#    ensure => present,
#  }
#  a2mod { 'proxy_http':
#    ensure => present,
#  }

  if $ssl_cert_file_contents != '' {
    file { $ssl_cert_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_cert_file_contents,
      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_key_file_contents != '' {
    file { $ssl_key_file:
      owner   => 'root',
      group   => 'ssl-cert',
      mode    => '0640',
      content => $ssl_key_file_contents,
      require => Package['ssl-cert'],
      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_chain_file_contents != '' {
    file { $ssl_chain_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_chain_file_contents,
      before  => Apache::Vhost[$vhost_name],
    }
  }

  $packages = [
    'python-babel',
    'python-sqlalchemy',  # devstack-gate
    'ssl-cert',
    'sqlite3', # interact with devstack-gate DB
  ]

  package { $packages:
    ensure => present,
  }

  package { 'jenkins':
    ensure  => present,
    require => Apt::Source['jenkins'],
  }

  exec { 'update apt cache':
    subscribe   => File['/etc/apt/sources.list.d/jenkins.list'],
    refreshonly => true,
    path        => '/bin:/usr/bin',
    command     => 'apt-get update',
  }

  file { '/var/lib/jenkins':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'adm',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0700',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa':
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0600',
    content => $jenkins_ssh_private_key,
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa.pub':
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0644',
    content => $jenkins_ssh_public_key,
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/plugins':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0750',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'nogroup',
    require => File['/var/lib/jenkins/plugins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack.css':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/jenkins/openstack.css',
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack.js':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    content => template('jenkins/openstack.js.erb'),
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/openstack-page-bkg.jpg':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/jenkins/openstack-page-bkg.jpg',
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/var/lib/jenkins/logger.conf':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/jenkins/logger.conf',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/plugins/simple-theme-plugin/title.png':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => "puppet:///modules/jenkins/${logo}",
    require => File['/var/lib/jenkins/plugins/simple-theme-plugin'],
  }

  file { '/usr/local/jenkins':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/usr/local/jenkins/slave_scripts':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
    purge   => true,
    force   => true,
    require => File['/usr/local/jenkins'],
    source  => 'puppet:///modules/jenkins/slave_scripts',
  }

  file { '/home/jenkins/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0700',
    require => Package['jenkins'],
  }

  file { '/home/jenkins/.ssh/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0700',
    require => File['/home/jenkins'],
  }

  file { '/home/jenkins/.ssh/id_rsa':
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0600',
    content => $jenkins_ssh_private_key,
    replace => true,
    require => File['/home/jenkins/.ssh/'],
  }

  file { '/home/jenkins/.ssh/id_rsa.pub':
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0644',
    content => $jenkins_ssh_public_key,
    replace => true,
    require => File['/home/jenkins/.ssh/'],
  }
  user { 'jenkins':
    ensure     => present,
    comment    => 'Jenkins User',
    home       => '/home/jenkins',
    gid        => 'jenkins',
    shell      => '/bin/bash',
    membership => 'minimum',
    groups     => $groups,
    require    => Group['jenkins'],
  }

  file { '/home/jenkins/.pip':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => File['/home/jenkins'],
  }

  file { '/home/jenkins/.gitconfig':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0640',
    source  => 'puppet:///modules/jenkins/gitconfig',
    require => File['/home/jenkins'],
  }
}
