class pdnsd::service inherits ::pdnsd {

  if $service_manage == true {
    service { 'pdnsd':
      ensure     => $service_ensure,
      enable     => $service_enable,
      name       => $service_name,
    }
  }
}
