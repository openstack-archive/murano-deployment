# Define: zabbix::server::alertscript
#
define zabbix::server::alertscript (
  $content = undef,
  $template = undef,
) {
  if($title) {
    file { "/etc/zabbix/alert.d/${title}" :
      ensure => 'present',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    if($content) {
      File <| title == "/etc/zabbix/alert.d/${title}" |> {
        source => $content,
      }
    }
    elsif($template) {
      File <| title == "/etc/zabbix/alert.d/${title}" |> {
        content => template($template),
      }
    }
  } else {
    fail('zabbix::server::alert invoked with empty name argument')
  }
}
