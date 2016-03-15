# Define: zabbix::item
#
define zabbix::item (
  $content     = undef,
  $items       = [],
  $raw_content = '',
  $template    = undef,
) {
  include zabbix::agent::service
  include zabbix::params

  $service = $::zabbix::params::agent_service

  ensure_resource('file', '/etc/zabbix/zabbix_agentd.conf.d', {
    ensure  => 'directory',
    require => Class['zabbix::agent']
  })

  if($title) {
    file { "/etc/zabbix/zabbix_agentd.conf.d/${title}.conf" :
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Class['zabbix::agent'],
      notify  => Service[$service],
    }
    if($content) {
      File <| title == "/etc/zabbix/zabbix_agentd.conf.d/${title}.conf" |> {
        source => $content,
      }
    }
    elsif($template) {
      File <| title == "/etc/zabbix/zabbix_agentd.conf.d/${title}.conf" |> {
        content => template($template),
      }
    }
  } else {
    fail('zabbix::item invoked with empty name argument')
  }
}
