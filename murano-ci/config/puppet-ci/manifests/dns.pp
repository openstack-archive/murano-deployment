$dns_hash = hiera_hash('dns', {})
$dns_servers_hash = pick($dns_hash['dns_servers'], {})
$server_listen_ip = pick($dns_hash['listen_addr'], "127.0.0.1")
$resolvconf_manage = pick($dns_hash['manage_resolvconf'], false)

class { 'pdnsd':
  preferred_servers => $dns_servers_hash,
  server_ip         => $server_listen_ip,
  manage_resolvconf => $resolvconf_manage,
}
