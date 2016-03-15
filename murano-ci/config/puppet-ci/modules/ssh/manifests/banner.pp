# Class: ssh::banner
#
# This class setup login banner file on host.
#
# Parameters:
#
#   [*content*] - banner contents
#
class ssh::banner (
  $content = '',
) {
  file { '/etc/banner' :
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => $content,
  }
}
