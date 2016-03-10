$monitoring_hash        = hiera_hash('monitoring', {})

$zabbix_start_agents           = pick($monitoring_hash['agent_start_agents'], {})
$zabbix_timeout                = pick($monitoring_hash['agent_timeout'], {})
$zabbix_server                 = pick($monitoring_hash['agent_zabbix_server'], {})
$zabbix_repo                   = pick($monitoring_hash['agent_zabbix_repo'], {})

include apt

if $zabbix_repo == 'http://mirror.fuel-infra.org/devops/ubuntu/' {

  $repo_release  = '/'
  $repo_repos    = ''
  $repo_key_id   = '0x62BF6A9C1D2B45A2'
  $repo_key_source = 'http://mirror.fuel-infra.org/devops/ubuntu/Release.key'

  apt::key { 'zabbix_repo_key':
    id       => $repo_key_id,
    source   => $repo_key_source;
  }

  apt::source { 'zabbix_repo':
    location => $zabbix_repo,
    release  => $repo_release,
    repos    => $repo_repos,
    require  => Apt::Key['zabbix_repo_key'];
  }

 exec { 'apt-get update':
    command => '/usr/bin/apt-get update',
    require => Apt::Source['zabbix_repo'],
    notify  => Class['::zabbix::agent'];
 }
}

class { '::zabbix::params':}

class {'::zabbix::agent':
  start_agents               => $zabbix_start_agents,
  timeout                    => $zabbix_timeout,
  zabbix_server              => $zabbix_server;
}
