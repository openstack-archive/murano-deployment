# Copyright 2012-2013 Hewlett-Packard Development Company, L.P.
# Copyright 2012 Antoine "hashar" Musso
# Copyright 2012 Wikimedia Foundation Inc.
# Copyright 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# == Class: zuul
#
class zuul (
  $vhost_name = $::fqdn,
  $serveradmin = "webmaster@${::fqdn}",
  $gearman_server = '127.0.0.1',
  $internal_gearman = true,
  $gerrit_server = '',
  $gerrit_user = '',
  $zuul_ssh_private_key = '',
  $url_pattern = '',
  $status_url = "https://127.0.0.1/zuul/status",
  $zuul_url = '',
  $git_source_repo = 'https://git.openstack.org/openstack-infra/zuul',
  $push_change_refs = false,
  $job_name_in_report = false,
  $revision = 'master',
  $git_email = '',
  $git_name = '',
  $statsd_host = ''
) {
  include apache
  include pip

  $packages = [
    'python-webob',
    'python-lockfile',
    'python-paste',
  ]

  package { $packages:
    ensure => present,
  }

  # A lot of things need yaml, be conservative requiring this package to avoid
  # conflicts with other modules.
  if ! defined(Package['python-yaml']) {
    package { 'python-yaml':
      ensure => present,
    }
  }

  if ! defined(Package['python-paramiko']) {
    package { 'python-paramiko':
      ensure   => present,
    }
  }

  if ! defined(Package['python-daemon']) {
    package { 'python-daemon':
      ensure => present,
    }
  }

  user { 'zuul':
    ensure     => present,
    home       => '/home/zuul',
    shell      => '/bin/bash',
    gid        => 'zuul',
    managehome => true,
    require    => Group['zuul'],
  }

  group { 'zuul':
    ensure => present,
  }

  file { '/home/zuul/.ssh':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
    require => User['zuul'],
  }

  file { '/home/zuul/.ssh/config':
    ensure  => present,
    owner   => 'zuul',
    group   => 'zuul',
    require => File['/home/zuul/.ssh'],
    content => template('zuul/ssh_config.erb'),
  }

  exec { 'git_user':
    command => 'su zuul -c "git config --global user.name \"murano-ci\""',
    path    => '/usr/bin:/bin',
    require => User['zuul'],
  }

  exec { 'git_mail':
    command => 'su zuul -c "git config --global user.email \"murano-en@mirantis.com\""',
    path    => '/usr/bin:/bin',
    require => Exec['git_user'],
  }

  vcsrepo { '/opt/zuul':
    ensure   => latest,
    provider => git,
    revision => $revision,
    source   => $git_source_repo,
  }

  exec { 'install_zuul' :
    command     => 'pip install /opt/zuul',
    path        => '/usr/local/bin:/usr/bin:/bin/',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/zuul'],
    require     => Class['pip'],
  }

  file { '/etc/zuul':
    ensure => directory,
  }

# TODO: We should put in  notify either Service['zuul'] or Exec['zuul-reload']
#       at some point, but that still has some problems.
  file { '/etc/zuul/zuul.conf':
    ensure  => present,
    owner   => 'zuul',
    mode    => '0400',
    content => template('zuul/zuul.conf.erb'),
    require => [
      File['/etc/zuul'],
      User['zuul'],
    ],
  }

  file { '/etc/default/zuul':
    ensure  => present,
    mode    => '0444',
    content => template('zuul/zuul.default.erb'),
  }

  file { '/var/log/zuul':
    ensure  => directory,
    owner   => 'zuul',
    require => User['zuul'],
  }

  file { '/var/run/zuul':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
    require => User['zuul'],
  }

  file { '/var/lib/zuul':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
  }

  file { '/var/lib/zuul/git':
    ensure  => directory,
    owner   => 'zuul',
    require => File['/var/lib/zuul'],
  }

  file { '/var/lib/zuul/ssh':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0500',
    require => File['/var/lib/zuul'],
  }

  file { '/var/lib/zuul/ssh/id_rsa':
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0400',
    require => File['/var/lib/zuul/ssh'],
    content => $zuul_ssh_private_key,
  }

  file { '/var/lib/zuul/www':
    ensure  => directory,
    require => File['/var/lib/zuul'],
  }

  package { 'libjs-jquery':
    ensure => present,
  }

  file { '/var/lib/zuul/www/jquery.min.js':
    ensure  => link,
    target  => '/usr/share/javascript/jquery/jquery.min.js',
    require => [File['/var/lib/zuul/www'],
                Package['libjs-jquery']],
  }

  vcsrepo { '/opt/jquery-visibility':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/mathiasbynens/jquery-visibility.git',
  }

  file { '/var/lib/zuul/www/jquery-visibility.min.js':
    ensure  => link,
    target  => '/opt/jquery-visibility/jquery-visibility.min.js',
    require => [File['/var/lib/zuul/www'],
                Vcsrepo['/opt/jquery-visibility']],
  }

  file { '/var/lib/zuul/www/index.html':
    ensure  => link,
    target  => '/opt/zuul/etc/status/public_html/index.html',
    require => File['/var/lib/zuul/www'],
  }

  file { '/var/lib/zuul/www/app.js':
    ensure  => link,
    target  => '/opt/zuul/etc/status/public_html/app.js',
    require => File['/var/lib/zuul/www'],
  }

  file { '/etc/init.d/zuul':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0555',
    source => 'puppet:///modules/zuul/zuul.init',
  }

  file { '/etc/init.d/zuul-merger':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0555',
    source => 'puppet:///modules/zuul/zuul-merger.init',
  }

#  exec { 'zuul-reload':
#    command     => '/etc/init.d/zuul reload',
#    require     => File['/etc/init.d/zuul'],
#    refreshonly => true,
#    notify      => Exec['jenkins-restart'],
#  }

#  exec { 'jenkins-restart':
#    command     => '/etc/init.d/jenkins restart',
#    refreshonly => true,
#  }

#  service { 'zuul':
#    name       => 'zuul',
#    enable     => true,
#    hasrestart => true,
#    require    => File['/etc/init.d/zuul'],
#  }

#  cron { 'zuul_repack':
#    user        => 'zuul',
#    weekday     => '0',
#    hour        => '4',
#    minute      => '7',
#    command     => 'find /var/lib/zuul/git/ -maxdepth 3 -type d -name ".git" -exec git --git-dir="{}" pack-refs --all \;',
#    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
#    require     => [User['zuul'],
#                    File['/var/lib/zuul/git']],
#  }

  apache::vhost { $vhost_name:
    port     => 443,
    docroot  => 'MEANINGLESS ARGUMENT',
    priority => '50',
    template => 'zuul/zuul.vhost.erb',
  }
  a2mod { 'rewrite':
    ensure => present,
  }
  a2mod { 'proxy':
    ensure => present,
  }
  a2mod { 'proxy_http':
    ensure => present,
  }
  a2mod { 'dav':
    ensure => present,
  }

  file { 'jenkins' :
    ensure  => present,
    path    => '/etc/apache2/conf.d/jenkins',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/jenkins/jenkins.conf',
  }

    Package <| title == 'httpd' |> -> File['jenkins']
}
