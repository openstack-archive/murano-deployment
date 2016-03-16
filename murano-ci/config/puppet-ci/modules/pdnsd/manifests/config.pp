class pdnsd::config inherits ::pdnsd{

  File {
    owner   => root,
    group   => root,
    mode    => '0644',
  }

  file { '/etc/default/pdnsd':
    ensure  => file,
    content => template("${module_name}/default_pdnsd.erb"),
  }

  file { '/etc/pdnsd.conf':
    require => Package['pdnsd'],
    ensure  => file,
    content => template("${module_name}/pdnsd.conf.erb"),
    notify  => Service['pdnsd'],
  }

  if $manage_resolvconf {
    file { '/etc/resolvconf/resolv.conf.d/head':
      ensure  => file,
      content => template("${module_name}/resolv.conf-head.erb"),
      notify  => Exec['resolvconf_refresh'],
    }

    exec { 'resolvconf_refresh':
      command => '/sbin/resolvconf -u',
    }
  }
}
