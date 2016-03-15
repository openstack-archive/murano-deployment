# Class: zabbix::server
#
class zabbix::server (
  $alert_script_path         = $::zabbix::params::server_alert_script_path,
  $allow_root                = $::zabbix::params::server_allow_root,
  $apply_firewall_rules      = $::zabbix::params::server_apply_firewall_rules,
  $cache_size                = $::zabbix::params::server_cache_size,
  $cache_update_frequency    = $::zabbix::params::server_cache_update_frequency,
  $config                    = $::zabbix::params::server_config,
  $config_template           = $::zabbix::params::server_config_template,
  $db_driver                 = $::zabbix::params::server_db_driver,
  $db_host                   = $::zabbix::params::server_db_host,
  $db_name                   = $::zabbix::params::server_db_name,
  $db_password               = $::zabbix::params::server_db_password,
  $db_port                   = $::zabbix::params::server_db_port,
  $db_socket                 = $::zabbix::params::server_db_socket,
  $db_user                   = $::zabbix::params::server_db_user,
  $debug_level               = $::zabbix::params::server_debug_level,
  $disable_housekeeping      = $::zabbix::params::server_disable_housekeeping,
  $enable_service            = $::zabbix::params::server_enable_service,
  $external_scripts          = $::zabbix::params::server_external_scripts,
  $firewall_allow_sources    = $::zabbix::params::server_firewall_allow_sources,
  $fping6_location           = $::zabbix::params::server_fping6_location,
  $fping_location            = $::zabbix::params::server_fping_location,
  $frontend_package          = $::zabbix::params::frontend_package,
  $frontend_service_fqdn     = $::zabbix::params::frontend_service_fqdn,
  $history_cache_size        = $::zabbix::params::server_history_cache_size,
  $history_text_cache_size   = $::zabbix::params::server_history_text_cache_size,
  $housekeeping_frequency    = $::zabbix::params::server_housekeeping_frequency,
  $install_frontend          = $::zabbix::params::server_install_frontend,
  $install_ping_handler      = $::zabbix::params::server_install_ping_handler,
  $listen_ip                 = $::zabbix::params::server_listen_ip,
  $listen_port               = $::zabbix::params::server_listen_port,
  $log_file                  = $::zabbix::params::server_log_file,
  $log_file_size             = $::zabbix::params::server_log_file_size,
  $log_slow_queries          = $::zabbix::params::server_log_slow_queries,
  $max_housekeeper_delete    = $::zabbix::params::server_max_housekeeper_delete,
  $mysql_package             = $::zabbix::params::mysql_package,
  $mysql_root_password       = $::zabbix::params::mysql_root_password,
  $node_id                   = $::zabbix::params::server_node_id,
  $node_no_events            = $::zabbix::params::server_node_no_events,
  $node_no_history           = $::zabbix::params::server_node_no_history,
  $package                   = $::zabbix::params::server_package,
  $pid_file                  = $::zabbix::params::server_pid_file,
  $sender_frequency          = $::zabbix::params::server_sender_frequency,
  $service                   = $::zabbix::params::server_service,
  $source_ip                 = $::zabbix::params::server_source_ip,
  $ssh_key_location          = $::zabbix::params::server_ssh_key_location,
  $start_db_syncers          = $::zabbix::params::server_start_db_syncers,
  $start_discoverers         = $::zabbix::params::server_start_discoverers,
  $start_http_pollers        = $::zabbix::params::server_start_http_pollers,
  $start_ipmi_pollers        = $::zabbix::params::server_start_ipmi_pollers,
  $start_java_pollers        = $::zabbix::params::server_start_java_pollers,
  $start_pingers             = $::zabbix::params::server_start_pingers,
  $start_pollers             = $::zabbix::params::server_start_pollers,
  $start_pollers_unreachable = $::zabbix::params::server_start_pollers_unreachable,
  $start_proxy_pollers       = $::zabbix::params::server_start_proxy_pollers,
  $start_snmp_trapper        = $::zabbix::params::server_start_snmp_trapper,
  $start_timers              = $::zabbix::params::server_start_timers,
  $start_trappers            = $::zabbix::params::server_start_trappers,
  $start_vmware_collectors   = $::zabbix::params::server_start_vmware_collectors,
  $timeout                   = $::zabbix::params::server_timeout,
  $tmp_dir                   = $::zabbix::params::server_tmp_dir,
  $trapper_timeout           = $::zabbix::params::server_trapper_timeout,
  $trend_cache_size          = $::zabbix::params::server_trend_cache_size,
  $unavailable_delay         = $::zabbix::params::server_unavailable_delay,
  $unreachable_delay         = $::zabbix::params::server_unreachable_delay,
  $unreachable_period        = $::zabbix::params::server_unreachable_period,
  $value_cache_size          = $::zabbix::params::server_value_cache_size,
) inherits ::zabbix::params {
  if ($install_frontend) {
    class { '::zabbix::frontend' :
      package              => $frontend_package,
      db_host              => $db_host,
      db_port              => $db_port,
      db_user              => $db_user,
      db_password          => $db_password,
      db_driver            => $db_driver,
      install_ping_handler => $install_ping_handler,
      service_fqdn         => $frontend_service_fqdn,
    }
  }

  class { '::mysql::server' :
    users     => {
      'zabbix@localhost' => {
        password_hash => mysql_password($db_password),
      },
      'zabbix@127.0.0.1' => {
        password_hash => mysql_password($db_password),
      }
    },
    databases => {
      'zabbix' => {
        charset => 'utf8',
      }
    },
    grants    => {
      'zabbix@localhost/zabbix.*' => {
        options    => ['GRANT'],
        privileges => ['ALTER', 'CREATE', 'INDEX', 'SELECT', 'INSERT', 'UPDATE', 'DELETE'],
        table      => 'zabbix.*',
        user       => 'zabbix@localhost',
      }
    }
  }

  exec { 'import-zabbix-fixtures' :
    command  => "zcat /usr/share/zabbix-server-mysql/schema.sql.gz | \
    mysql -h'${db_host}' -u'${db_user}' -p'${db_password}' '${db_name}'",
    provider => 'shell',
    creates  => '/etc/zabbix/zabbix_server_installed.flag',
    require  => [Class['::mysql::server'], Package[$package]]
  }->
  exec { 'load-zabbix-images' :
    command  => "zcat /usr/share/zabbix-server-mysql/images.sql.gz | \
    mysql -h'${db_host}' -u'${db_user}' -p'${db_password}' '${db_name}'",
    provider => 'shell',
    creates  => '/etc/zabbix/zabbix_server_installed.flag',
  }->
  exec { 'load-zabbix-initial-data' :
    command  => "zcat /usr/share/zabbix-server-mysql/data.sql.gz | \
    mysql -h'${db_host}' -u'${db_user}' -p'${db_password}' '${db_name}'",
    provider => 'shell',
    creates  => '/etc/zabbix/zabbix_server_installed.flag',
  }->
  exec { 'flag-installation-complete' :
    command  => 'touch /etc/zabbix/zabbix_server_installed.flag',
    provider => 'shell',
    notify   => Service[$service],
  }

  file { '/etc/default/zabbix-server' :
    ensure  => 'present',
    content => template('zabbix/server/zabbix_server_default.erb'),
    require => Package[$package],
  }

  package { $package :
    ensure  => 'present',
    require => Class['::mysql::server']
  }

  if ($apply_firewall_rules) {
    include firewall_defaults::pre
    create_resources(firewall, $firewall_allow_sources, {
      dport   => 10051,
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    })
  }

  file { $config :
    ensure  => 'present',
    owner   => 'zabbix',
    group   => 'zabbix',
    mode    => '0400',
    content => template('zabbix/server/zabbix_server.conf.erb'),
    require => Package[$package],
    notify  => Service[$service],
  }

  $ensure_status = $enable_service ? {
    true  => 'running',
    false => 'stopped',
  }

  service { $service :
    ensure     => $ensure_status,
    enable     => $enable_service,
    hasstatus  => true,
    hasrestart => true,
    require    => [
      Package[$package],
      File[$config],
    ]
  }

  if ($::osfamily == 'Debian') {
    Service[$service] {
      provider => 'debian'
    }
  }
}
