$zuul_hash                      = hiera_hash('zuul', {})
$project_config_hash            = hiera_hash('project_config', {})
$custom_config_hash             = hiera_hash('custom_config', {})
$git_source_hash                = hiera_hash('git_source', {})

$gerrit_hash                    = pick($zuul_hash['gerrit'], {})
$swift_hash                     = pick($zuul_hash['swift'], {})
$ssl_hash                       = pick($zuul_hash['ssl'], {})
$smtp_hash                      = pick($zuul_hash['smtp'], {})

$vhost_name                     = pick_default($zuul_hash['vhost'], hiera('hostname'), $::fqdn)
$gearman_server                 = pick_default($zuul_hash['gearman'], '127.0.0.1')

$gerrit_server                  = pick_default($gerrit_hash['server'], 'review.openstack.org')
$gerrit_user                    = pick_default($gerrit_hash['user'], 'zuul')
$zuul_ssh_private_key           = pick_default($gerrit_hash['private_key'], '')

$known_hosts_content            = pick_default($zuul_hash['known_hosts'], 'review.openstack.org,23.253.232.87,2001:4800:7815:104:3bc3:d7f6:ff03:bf5d b8:3c:72:82:d5:9e:59:43:54:11:ef:93:40:1f:6d:a5')

$url_pattern                    = pick_default($zuul_hash['url_pattern'], '')
$job_name_in_report             = pick_default($zuul_hash['job_name_in_report'], true)

$zuul_url                       = pick_default($zuul_hash['zuul_url'], "http://${fqdn}/p")
$status_url                     = pick_default($zuul_hash['status_url'], "http://${vhost_name}/zuul")

$swift_authurl                  = pick_default($swift_hash['auth_url'], '')
$swift_auth_version             = pick_default($swift_hash['auth_version'], '')
$swift_user                     = pick_default($swift_hash['user'], '')
$swift_key                      = pick_default($swift_hash['key'], '')
$swift_tenant_name              = pick_default($swift_hash['tenant'], '')
$swift_region_name              = pick_default($swift_hash['region'], '')
$swift_default_container        = pick_default($swift_hash['default_container'], '')
$swift_default_logserver_prefix = pick_default($swift_hash['default_logserver_prefix'], '')
$swift_default_expiry           = pick_default($swift_hash['default_expiry'], 7200)

$proxy_ssl_cert_file_contents   = pick_default($ssl_hash['cert'], '')
$proxy_ssl_key_file_contents    = pick_default($ssl_hash['key'], '')
$proxy_ssl_chain_file_contents  = pick_default($ssl_hash['chain'], '')

$statsd_host                    = pick_default($zuul_hash['statsd'], hiera('statsd', ''), '')

$project_config_repo            = pick_default($project_config_hash['repository'], '')
$project_config_base            = pick_default($project_config_hash['base'], '')
$project_config_rev             = pick_default($project_config_hash['revision'], 'master')

$git_email                      = pick_default($zuul_hash['git_email'], "zuul@${vhost_name}")
$git_name                       = pick_default($zuul_hash['git_name'], 'Zuul')

$smtp_host                      = pick_default('127.0.0.1')
$smtp_port                      = pick_default($smtp_hash['port'], 25)
$smtp_default_from              = pick_default($smtp_hash['from'], "zuul@${::fqdn}")
$smtp_default_to                = pick_default($smtp_hash['to'], "zuul.reports@${::fqdn}")

$zuul_source_hash               = pick($git_source_hash['zuul'], {})
$git_source_repo                = pick($zuul_source_hash['repository'], 'https://git.openstack.org/openstack-infra/zuul')
$revision                       = pick($zuul_source_hash['revision'], 'master')

#vhost config for murano-ci (jenkins, nodepool, zuul, logs on the same host)
$custom_vhost                   = pick($custom_config_hash['custom_vhost'], false)
$builds_archive_dir             = pick($custom_config_hash['builds_archive_dir'], '')

###

if ! defined(Class['project_config']) {
  class { 'project_config':
    url      => $project_config_repo,
    revision => $project_config_revision,
    base     => $project_config_base,
  }
}

class { '::zuul':
  vhost_name                     => $vhost_name,
  gearman_server                 => $gearman_server,

  gerrit_server                  => $gerrit_server,
  gerrit_user                    => $gerrit_user,

  zuul_ssh_private_key           => $zuul_ssh_private_key,
  zuul_url                       => $zuul_url,

  git_email                      => $git_email,
  git_name                       => $git_name,

  revision                       => $revision,
  git_source_repo                => $git_source_repo,

  url_pattern                    => $url_pattern,
  job_name_in_report             => $job_name_in_report,

  status_url                     => $status_url,
  statsd_host                    => $statsd_host,

  smtp_host                      => $smtp_host,
  smtp_port                      => $smtp_port,
  smtp_default_from              => $smtp_default_from,
  smtp_default_to                => $smtp_default_to,

  swift_authurl                  => $swift_authurl,
  swift_auth_version             => $swift_auth_version,
  swift_user                     => $swift_user,
  swift_key                      => $swift_key,
  swift_tenant_name              => $swift_tenant_name,
  swift_region_name              => $swift_region_name,
  swift_default_container        => $swift_default_container,
  swift_default_logserver_prefix => $swift_default_logserver_prefix,
  swift_default_expiry           => $swift_default_expiry,

  proxy_ssl_cert_file_contents   => $proxy_ssl_cert_file_contents,
  proxy_ssl_key_file_contents    => $proxy_ssl_key_file_contents,
  proxy_ssl_chain_file_contents  => $proxy_ssl_chain_file_contents,
}

if $custom_vhost {

  Httpd::Vhost<| title == $vhost_name |> {
    template   => 'muranoci-extras/vhost_custom.conf.erb',
  }

}


class { '::zuul::server':
  layout_dir => $::project_config::zuul_layout_dir,
  require    => $::project_config::config_dir,
}

class { '::zuul::merger': }

if $known_hosts_content != '' {
  file { '/home/zuul/.ssh':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0700',
    require => Class['::zuul'],
  }

  file { '/home/zuul/.ssh/known_hosts':
    ensure  => present,
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0600',
    content => $known_hosts_content,
    replace => true,
    require => File['/home/zuul/.ssh'],
  }
}

