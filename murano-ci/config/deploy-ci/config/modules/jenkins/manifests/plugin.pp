#
# Defined resource type to install jenkins plugins.
#
# Borrowed from: https://github.com/jenkinsci/puppet-jenkins
#

define jenkins::plugin(
  $local_dir='',
  $version=0,
) {
  $plugin            = "${name}.hpi"
  $plugin_dir        = '/var/lib/jenkins/plugins'
  $plugin_parent_dir = '/var/lib/jenkins'

  if ($local_dir != '') {
    $base_url   = 'file://${local_dir}'
  }
  elsif ($version != 0) {
    $base_url = "http://updates.jenkins-ci.org/download/plugins/${name}/${version}"
  }
  else {
    $base_url   = 'http://updates.jenkins-ci.org/latest'
  }

  if (!defined(File[$plugin_dir])) {
    file {
      [
        $plugin_parent_dir,
        $plugin_dir,
      ]:
        ensure  => directory,
        owner   => 'jenkins',
        group   => 'jenkins',
        require => [Group['jenkins'], User['jenkins']],
    }
  }

  if (!defined(Group['jenkins'])) {
    group { 'jenkins' :
      ensure => present,
    }
  }

  if (!defined(User['jenkins'])) {
    user { 'jenkins' :
      ensure => present,
    }
  }
  if ($local_dir == '') {
    exec { "download-${name}" :
      command  => "wget --no-check-certificate ${base_url}/${plugin}",
      cwd      => $plugin_dir,
      require  => File[$plugin_dir],
      path     => ['/usr/bin', '/usr/sbin',],
      user     => 'jenkins',
      unless   => "test -f ${plugin_dir}/${name}.?pi",
#    OpenStack modification: don't auto-restart jenkins so we can control
#    outage timing better.
#    notify   => Service['jenkins'],
  }
  }
  else {
    exec { "copy-${name}" :
      command  => "cp ${local_dir}/${plugin} .",
      cwd      => $plugin_dir,
      require  => File[$plugin_dir],
      path     => ['/usr/bin', '/usr/sbin', '/bin',],
      user     => 'jenkins',
  }
  }
}
