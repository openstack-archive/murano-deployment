class pdnsd::install inherits ::pdnsd {

  package { 'pdnsd':
    ensure => $package_ensure,
    name   => $package_name,
  }

}
