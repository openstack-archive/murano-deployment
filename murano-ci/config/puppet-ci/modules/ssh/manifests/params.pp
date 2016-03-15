# Class: ssh::params
#
# This class contains default parameters for ssh on host.
#
# Parameters:
#   [*apply_firewall_rules*] - apply embedded firewall rules
#   [*bind_policy*] - bind policy type
#   [*firewall_allow_sources*] - sources which are allowed to contact this
#   [*ldap_ignore_users*] - users ignored in this authentication model
#   [*pam_password*] - pam password hash type
#   [*packages*] - packages required to deploy ssh daemon
#   [*ldap_packages*] - packages required for ldap authentication
#   [*service*] - ssh service name
#
class ssh::params {
  $apply_firewall_rules   = false
  $bind_policy            = 'soft'
  $firewall_allow_sources = {}
  $ldap_ignore_users      = 'backup,bin,daemon,games,gnats,irc,landscape,libuuid,list,lp,mail,man,messagebus,mysql,nagios,news,ntp,postfix,proxy,puppet,root,sshd,sync,sys,syslog,uucp,whoopsie,www-data,zabbix'
  $pam_password           = 'md5'

  $packages = [
    'openssh-server'
  ]

  case $::osfamily {
    'RedHat': {
      $ldap_packages = [
        'openldap',
        'nss-pam-ldapd',
        'nscd',
      ]
      $service = 'sshd'
    }
    'Debian': {
      $ldap_packages = [
        'ldap-utils',
        'libpam-ldap',
        'nscd',
      ]
      $service = 'ssh'
    }
    default: {
      fatal("Unknown osfamily: ${::osfamily}. Probaly your OS is unsupported.")
    }
  }

  $sshd_config = '/etc/ssh/sshd_config'
}
