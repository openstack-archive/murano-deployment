# Class: zabbix::params
#
class zabbix::params {
  #
  # Agent default configuration
  #
  $agent_allow_root             = false
  $agent_apply_firewall_rules   = false
  $agent_debug_level            = 3
  $agent_enable_remote_commands = true
  $agent_firewall_allow_sources = {
    '1000 - zabbix connections allow' => {
      source => '127.0.0.1/32',
    }
  }
  $agent_hostname                   = $::fqdn
  $agent_hostname_item              = $::fqdn
  $agent_include                    = '/etc/zabbix/zabbix_agentd.conf.d/'
  $agent_listen_address             = '0.0.0.0'
  $agent_listen_port                = 10050
  $agent_log_remote_commands        = true
  $agent_max_lines_per_second       = 100
  $agent_package                    = 'zabbix-agent'
  $agent_refresh_active_checks      = 120
  $agent_server_active              = undef
  $agent_service                    = 'zabbix-agent'
  $agent_start_agents               = 2
  $agent_sudoers_template           = 'zabbix/sudoers.erb'
  $agent_timeout                    = 5
  $agent_unsafe_user_parameters     = false
  $agent_zabbix_server              = '127.0.0.1'

  #
  # Frontend default configuration
  #
  $frontend_apply_firewall_rules    = false
  $frontend_config                  = '/etc/zabbix/zabbix.conf.php'
  $frontend_config_temlate          = 'zabbix/frontend/zabbix.conf.php.erb'
  $frontend_config_template         = 'zabbix/frontend/zabbix.conf.php.erb'
  $frontend_db_driver               = 'MYSQL'
  $frontend_db_host                 = '127.0.0.1'
  $frontend_db_name                 = 'zabbix'
  $frontend_db_password             = ''
  $frontend_db_port                 = 3306
  $frontend_db_schema               = ''
  $frontend_db_socket               = undef
  $frontend_db_user                 = 'zabbix'
  $frontend_firewall_allow_sources  = {}
  $frontend_image_format_default    = 'IMAGE_FORMAT_PNG'
  $frontend_install_ping_handler    = false
  $frontend_nginx_access_log        = '/var/log/nginx/access.log'
  $frontend_nginx_config_template   = 'zabbix/frontend/nginx.conf.erb'
  $frontend_nginx_error_log         = '/var/log/nginx/error.log'
  $frontend_nginx_log_format        = undef
  $frontend_package                 = 'zabbix-frontend-php'
  $frontend_ping_handler_template   = 'zabbix/frontend/ping.php.erb'
  $frontend_service_fqdn            = $::fqdn
  $frontend_ssl_certificate         = undef
  $frontend_ssl_certificate_content = undef
  $frontend_ssl_key                 = undef
  $frontend_ssl_key_content         = undef
  $frontend_zabbix_server           = '127.0.0.1'
  $frontend_zabbix_server_name      = $::fqdn
  $frontend_zabbix_server_port      = '10051'

  #
  # Proxy default configuration
  #
  $proxy_apply_firewall_rules      = false
  $proxy_cache_size                = '8M'
  $proxy_config                    = '/etc/zabbix/zabbix_proxy.conf'
  $proxy_config_frequency          = 3600
  $proxy_config_template           = 'zabbix/proxy/zabbix_proxy.conf.erb'
  $proxy_data_sender_frequency     = 1
  #$proxy_db_driver
  $proxy_db_host                   = '127.0.0.1'
  $proxy_db_name                   = 'zabbix'
  $proxy_db_password               = 'zabbix'
  $proxy_db_port                   = 3306
  $proxy_db_socket                 = undef
  $proxy_db_user                   = 'zabbix'
  $proxy_debug_level               = 3
  $proxy_enable_snmp_bulk_requests = true
  $proxy_external_scripts          = '/etc/zabbix/external.d'
  $proxy_firewall_allow_sources    = {}
  $proxy_fping6_location           = '/usr/bin/fping6'
  $proxy_fping_location            = '/usr/bin/fping'
  $proxy_heartbeat_frequency       = '60'
  $proxy_history_cache_size        = '8M'
  $proxy_history_text_cache_size   = '16M'
  $proxy_hostname                  = $::fqdn
  $proxy_hostname_item             = 'system.hostname'
  $proxy_housekeeping_frequency    = '1'
  $proxy_include                   = undef
  $proxy_java_gateway              = undef
  $proxy_java_gateway_port         = 10052
  $proxy_listen_ip                 = '0.0.0.0'
  $proxy_listen_port               = '10051'
  $proxy_load_module               = undef
  $proxy_load_module_path          = undef
  $proxy_local_buffer              = '0'
  $proxy_log_file_size             = '1'
  $proxy_log_slow_queries          = '0'
  $proxy_mode                      = 'passive'
  $proxy_offline_buffer            = '1'
  $proxy_package                   = 'zabbix-proxy-mysql'
  $proxy_pid_file                  = '/var/run/zabbix/zabbix_proxy.pid'
  $proxy_server                    = undef
  $proxy_server_port               = '10051'
  $proxy_service                   = 'zabbix-proxy'
  $proxy_snmp_trapper_file         = '/tmp/zabbix_traps.tmp'
  $proxy_source_ip                 = undef
  $proxy_ssh_key_location          = undef
  $proxy_start_db_syncers          = '4'
  $proxy_start_discoverers         = '1'
  $proxy_start_http_pollers        = '1'
  $proxy_start_ipmi_pollers        = '0'
  $proxy_start_java_pollers        = '0'
  $proxy_start_pingers             = '1'
  $proxy_start_pollers             = '5'
  $proxy_start_pollers_unreachable = '1'
  $proxy_start_snmp_trapper        = false
  $proxy_start_trappers            = '5'
  $proxy_start_vmware_collectors   = '0'
  $proxy_timeout                   = '3'
  $proxy_tmp_dir                   = '/tmp'
  $proxy_trapper_timeout           = '300'
  $proxy_unavailable_delay         = '60'
  $proxy_unreachable_delay         = '15'
  $proxy_unreachable_period        = '300'
  $proxy_vmware_cache_size         = '8M'
  $proxy_vmware_frequency          = '60'

  #
  # Server default configuration
  #
  $server_alert_script_path         = '/etc/zabbix/alert.d/'
  $server_allow_root                = false
  $server_apply_firewall_rules      = false
  $server_cache_size                = '8M'
  $server_cache_update_frequency    = 60
  $server_config                    = '/etc/zabbix/zabbix_server.conf'
  $server_config_template           = 'zabbix/server/zabbix_server.conf.erb'
  $server_db_driver                 = 'mysql'
  $server_db_host                   = '127.0.0.1'
  $server_db_name                   = 'zabbix'
  $server_db_password               = ''
  $server_db_port                   = 3306
  $server_db_socket                 = undef
  $server_db_user                   = 'zabbix'
  $server_debug_level               = 3
  $server_enable_service            = true
  $server_firewall_allow_sources    = {}
  $server_fping6_location           = '/usr/bin/fping6'
  $server_fping_location            = '/usr/bin/fping'
  $server_history_cache_size        = floor($::memorysize_mb/128*1024*1024)
  $server_history_text_cache_size   = floor($::memorysize_mb/128*1024*1024)
  $server_housekeeping_frequency    = 1
  $server_install_frontend          = false
  $server_install_ping_handler      = false
  $server_listen_ip                 = '0.0.0.0'
  $server_listen_port               = 10051
  $server_log_file_size             = 0
  $server_log_slow_queries          = true
  $server_max_housekeeper_delete    = 500
  $server_node_id                   = undef
  $server_node_no_events            = false
  $server_node_no_history           = false
  $server_package                   = 'zabbix-server-mysql'
  $server_pid_file                  = '/var/run/zabbix/zabbix_server.pid'
  $server_sender_frequency          = 120
  $server_service                   = 'zabbix-server'
  $server_start_db_syncers          = 1
  $server_start_discoverers         = 2
  $server_start_http_pollers        = 2
  $server_start_ipmi_pollers        = 2
  $server_start_java_pollers        = 0
  $server_start_pingers             = 2
  $server_start_pollers             = 2
  $server_start_pollers_unreachable = 2
  $server_start_proxy_pollers       = 2
  $server_start_snmp_trapper        = 2
  $server_start_timers              = 2
  $server_start_trappers            = 2
  $server_start_vmware_collectors   = 2
  $server_timeout                   = 5
  $server_tmp_dir                   = '/tmp'
  $server_trapper_timeout           = 300
  $server_trend_cache_size          = floor($::memorysize_mb/128*1024*1024)
  $server_unavailable_delay         = 60
  $server_unreachable_delay         = 15
  $server_unreachable_period        = 45
  $server_value_cache_size          = floor($::memorysize_mb/128*1024*1024)

  #
  # MySQL default configuration
  #
  $mysql_package       = 'mysql-server'
  $mysql_root_password = ''

  case $::osfamily {
    'RedHat': {
      $agent_log_file  = '/var/log/zabbix/zabbix_agentd.log'
      $server_log_file = '/var/log/zabbix/zabbix_server.log'
      $proxy_log_file  = '/var/log/zabbix/zabbix_proxy.log'
    }
    'Debian': {
      $agent_log_file  = '/var/log/zabbix-agent/zabbix_agentd.log'
      $server_log_file = '/var/log/zabbix-server/zabbix_server.log'
      $proxy_log_file  = '/var/log/zabbix-proxy/zabbix_proxy.log'
    }
    default: {
      fatal("Unknown osfamily: ${::osfamily}. Probaly your OS is unsupported.")
    }
  }
}
