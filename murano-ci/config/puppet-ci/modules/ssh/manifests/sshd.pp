# Class: ssh::sshd
#
# This class deploys sshd service on host.
#
# Parameters:
#   [*apply_firewall_rules*] - apply embedded firewall rules
#   [*firewall_allow_sources*] - sources which are allowed to contact this
#   [*password_authentication*] - enable password authentication
#   [*sftp_group*] - a group which allows sftp connections
#
class ssh::sshd (
  $apply_firewall_rules    = $::ssh::params::apply_firewall_rules,
  $firewall_allow_sources  = $::ssh::params::firewall_allow_sources,
  $password_authentication = false,
  $sftp_group              = 'sftpusers',
) {
  include ssh::params

  $packages = $ssh::params::packages
  $service = $ssh::params::service
  $sshd_config = $ssh::params::sshd_config

  package { $packages :
    ensure => latest,
  }

  file { $sshd_config :
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('ssh/sshd_config.erb'),
    notify  => Service[$service],
  }

  service { $service :
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => false,
  }

  if ($apply_firewall_rules) {
    include firewall_defaults::pre
    create_resources(firewall, $firewall_allow_sources, {
      dport   => 22,
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    })
  }

}
