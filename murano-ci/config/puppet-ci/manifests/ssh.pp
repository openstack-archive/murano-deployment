$ssh_hash=hiera_hash('ssh', {})

$ssh_password_auth=pick($ssh_hash['password_authentication'],false)

class { '::ssh::params': }

class { '::ssh::sshd':
  password_authentication => $ssh_password_auth,
}