# Class: zabbix::agent
#
class zabbix::agent (
  $allow_root             = $::zabbix::params::agent_allow_root,
  $apply_firewall_rules   = $::zabbix::params::agent_apply_firewall_rules,
  $debug_level            = $::zabbix::params::agent_debug_level,
  $enable_remote_commands = $::zabbix::params::agent_enable_remote_commands,
  $firewall_allow_sources = $::zabbix::params::agent_firewall_allow_sources,
  $hostname               = $::zabbix::params::agent_hostname,
  $hostname_item          = $::zabbix::params::agent_hostname_item,
  $include                = $::zabbix::params::agent_include,
  $listen_address         = $::zabbix::params::agent_listen_address,
  $listen_port            = $::zabbix::params::agent_listen_port,
  $log_file               = $::zabbix::params::agent_log_file,
  $log_remote_commands    = $::zabbix::params::agent_log_remote_commands,
  $max_lines_per_second   = $::zabbix::params::agent_max_lines_per_second,
  $package                = $::zabbix::params::agent_package,
  $refresh_active_checks  = $::zabbix::params::agent_refresh_active_checks,
  $server_active          = $::zabbix::params::agent_server_active,
  $service                = $::zabbix::params::agent_service,
  $start_agents           = $::zabbix::params::agent_start_agents,
  $sudoers_template       = $::zabbix::params::agent_sudoers_template,
  $timeout                = $::zabbix::params::agent_timeout,
  $unsafe_user_parameters = $::zabbix::params::agent_unsafe_user_parameters,
  $zabbix_server          = $::zabbix::params::agent_zabbix_server,
) inherits ::zabbix::params {
  include zabbix::params
  include zabbix::agent::service

  if ! defined(Package[$package]) {
    package { $package :
      ensure      => 'present',
    }
  }

  file { '/etc/zabbix/zabbix_agentd.conf' :
    notify  => Service[$service],
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('zabbix/agent/zabbix_agentd.conf.erb'),
    require => Package[$package],
  }
  file { '/etc/sudoers.d/zabbix' :
    notify  => Service[$service],
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => template($sudoers_template)
  }

  if ($apply_firewall_rules) {
    include firewall_defaults::pre
    create_resources(firewall, $firewall_allow_sources, {
      dport   => 10050,
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    })
  }
}
