$mysql_hash                = hiera_hash('mysql', {})
$nodepool_hash             = hiera_hash('nodepool', {})
$git_source_hash           = hiera_hash('git_source', {})
$project_config_hash       = hiera_hash('project_config', {})

$jenkins_masters           = pick($nodepool_hash['jenkins'], {})

$mysql_root_password       = pick_default($mysql_hash['root_password'], '')
$mysql_password            = pick_default($mysql_hash['root_password'], '')

$yaml_path                 = pick_default($nodepool_hash['config_path'], '/etc/project-config/nodepool/nodepool.yaml')

$nodepool_source_hash      = pick($git_source_hash['nodepool'], {})
$git_source_repo           = pick($nodepool_source_hash['repository'], 'https://git.openstack.org/openstack-infra/nodepool')
$revision                  = pick($nodepool_source_hash['revision'], 'master')

$env                       = pick_default($nodepool_hash['env'], {})
$nodepool_ssh_private_key  = pick_default($nodepool_hash['private_key'], '')
$vhost_name                = pick_default($nodepool_hash['vhost'], hiera('hostname'), $::fqdn)
$statsd_host               = pick_default($nodepool_hash['statsd'], hiera('statsd', ''), '')
$image_log_document_root   = pick_default($nodepool_hash['image_log_dir'], '/var/log/nodepool/image')
$enable_image_log_via_http = pick_default($nodepool_hash['image_log_enabled'], true)

$project_config_repo       = pick_default($project_config_hash['repository'], '')
$project_config_base       = pick_default($project_config_hash['base'], '')
$project_config_rev        = pick_default($project_config_hash['revision'], 'master')

$logging_conf_template     = 'nodepool/nodepool.logging.conf.erb'

###

if ! defined(Class['project_config']) {
  class { 'project_config':
    url      => $project_config_repo,
    revision => $project_config_rev,
    base     => $project_config_base,
  }
}

class { '::nodepool':
  mysql_root_password       => $mysql_root_password,
  mysql_password            => $mysql_password,
  nodepool_ssh_private_key  => $nodepool_ssh_private_key,
  git_source_repo           => $git_source_repo,
  revision                  => $revision,
  vhost_name                => $vhost_name,
  statsd_host               => $statsd_host,
  image_log_document_root   => $image_log_document_root,
  enable_image_log_via_http => $enable_image_log_via_http,
  environment               => $env,
  scripts_dir               => $::project_config::nodepool_scripts_dir,
  elements_dir              => $::project_config::nodepool_elements_dir,
  require                   => $::project_config::config_dir,
  logging_conf_template     => $logging_conf_template,
  jenkins_masters           => $jenkins_masters,
}

file { '/etc/nodepool/nodepool.yaml':
  ensure  => present,
  source  => $yaml_path,
  owner   => 'nodepool',
  group   => 'root',
  mode    => '0400',
  require => [
    File['/etc/nodepool'],
    User['nodepool'],
    Class['project_config'],
  ],
}
