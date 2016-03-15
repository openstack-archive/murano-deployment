$ntp_servers = hiera('ntp_servers')
$ntp_servers_list = split($ntp_servers, ',')

class { '::ntp':
  servers  => $ntp_servers_list,
  restrict => ['127.0.0.1'],
}