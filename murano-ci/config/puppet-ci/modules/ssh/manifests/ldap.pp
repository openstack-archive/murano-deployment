# Class: ssh::ldap
#
# This class sets up ldap authorization on particular machine.
#
# Parameters:
#   [*bind_policy*] - bind policy type
#   [*ldap_base*] - ldap base for authentication
#   [*ldap_ignore_users*] - users ignored in this authentication model
#   [*ldap_uri*] - ldap URI
#   [*pam_filter*] - pam filter used by setup
#   [*pam_password*] - pam password hash type
#   [*sudoers_base*] - ldap sudoers base
#   [*tls_cacertdir*] - directory with ca certificates path
#
class ssh::ldap (
  $bind_policy       = $ssh::params::bind_policy,
  $ldap_base         = '',
  $ldap_ignore_users = $ssh::params::ldap_ignore_users,
  $ldap_uri          = '',
  $pam_filter        = '',
  $pam_password      = $ssh::params::pam_password,
  $sudoers_base      = '',
  $tls_cacertdir     = '',
) {
  include ssh::params

  include ssh::banner
  include ssh::sshd

  $ldap_packages = $ssh::params::ldap_packages

  package { $ldap_packages :
    ensure => 'present',
  }

  case $::osfamily {
    'Debian': {
      $etc_ldap_dir = '/etc/ldap'
    }
    'RedHat': {
      $etc_ldap_dir = '/etc/openldap'
    }
    default: { }
  }

  file { '/etc/ldap.conf':
    ensure  => 'present',
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => template('ssh/ldap.conf.erb'),
  }

  file { "${etc_ldap_dir}/ldap.conf" :
    ensure => 'link',
    target => '/etc/ldap.conf',
  }

  file { '/etc/nsswitch.conf':
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('ssh/nsswitch.conf.erb'),
    notify  => Service['nscd'],
  }

  file { '/etc/pam.d/common-session' :
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('ssh/common-session.erb'),
  }

  service { 'nscd' :
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => false,
  }

  Class['ssh::sshd']->
    Package[$ldap_packages]->
    File['/etc/ldap.conf']->
    File["${etc_ldap_dir}/ldap.conf"]->
    File['/etc/nsswitch.conf']->
    File['/etc/pam.d/common-session']->
    Service['nscd']
}