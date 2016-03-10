# Class: zabbix::agent::service
#
class zabbix::agent::service {
  include zabbix::params

  $service = $zabbix::params::agent_service

  service { $service :
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  if ($::osfamily == 'Debian') {
    Service[$service] {
      provider => 'debian'
    }
  }
}
