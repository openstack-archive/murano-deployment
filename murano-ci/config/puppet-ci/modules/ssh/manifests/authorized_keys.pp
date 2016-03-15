# Class: ssh::authorized_keys
#
# This class setup authorized SSH keys for root user.
#
class ssh::authorized_keys {
  $keys = hiera_hash('ssh::authorized_keys::keys', {})
  create_resources(ssh_authorized_key,
    $keys, {
      ensure => present,
      user => 'root'
    }
  )
}
