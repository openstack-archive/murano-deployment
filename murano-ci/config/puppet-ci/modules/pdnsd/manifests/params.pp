class pdnsd::params {

  $package_ensure     = 'present'
  $service_enable     = true
  $service_ensure     = 'running'
  $service_manage     = true
  $server_ip          = '127.0.0.1'

  $perm_cache         = 16384
  $cache_dir          = '/var/cache/pdnsd'
  $start_daemon       = 'yes'
  $preferred_servers  = undef

  $package_name    = 'pdnsd'
  $service_name    = 'pdnsd'

  $manage_resolvconf   = false

}
