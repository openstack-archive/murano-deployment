class pdnsd (
  $package_ensure    = $::pdnsd::params::package_ensure,
  $service_enable    = $::pdnsd::params::service_enable,
  $service_ensure    = $::pdnsd::params::service_ensure,
  $service_manage    = $::pdnsd::params::service_manage,
  $server_ip         = $::pdnsd::params::server_ip,

  $perm_cache        = $::pdnsd::params::perm_cache,
  $cache_dir         = $::pdnsd::params::cache_dir,
  $start_daemon      = $::pdnsd::params::start_daemon,
  $preferred_servers = $::pdnsd::params::preferred_servers,

  $package_name      = $::pdnsd::params::package_name,
  $service_name      = $::pdnsd::params::service_name,
  $manage_resolvconf = $::pdnsd::params::manage_resolvconf,
) inherits ::pdnsd::params {

  include ::pdnsd::install
  include ::pdnsd::config
  include ::pdnsd::service

}
