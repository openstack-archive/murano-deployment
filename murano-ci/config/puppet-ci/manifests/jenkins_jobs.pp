$jenkins_hash            = hiera_hash('jenkins', {})
$jenkins_job_hash        = pick($jenkins_hash['jobs'], {})
$project_config_hash     = hiera_hash('project_config', {})
$git_source_hash         = hiera_hash('git_source', {})

$jenkins_job_builder     = pick($git_source_hash['jenkins_job_buidler'], {})

$jenkins_username        = pick_default($jenkins_hash['user'], 'jenkins')
$jenkins_password        = pick_default($jenkins_hash['password'], '')

$jenkins_url             = pick_default($jenkins_job_hash['jenkins_url'], "http://127.0.0.1:8080")
$jjb_update_timeout      = 1200
$jjb_git_url             = pick($jenkins_job_builder['repository'], 'https://git.openstack.org/openstack-infra/jenkins-job-builder')
$jjb_git_revision        = pick($jenkins_job_builder['revision'], 'master')

$project_config_repo     = pick_default($project_config_hash['repository'], '')
$project_config_base     = pick_default($project_config_hash['base'], '')
$project_config_rev      = pick_default($project_config_hash['revision'], 'master')

if ! defined(Class['project_config']) {
  class { 'project_config':
    url      => $project_config_repo,
    revision => $project_config_rev,
    base     => $project_config_base,
  }
}

class { '::jenkins::job_builder':
  url                         => $jenkins_url,
  username                    => $jenkins_username,
  password                    => $jenkins_password,
  jenkins_jobs_update_timeout => $jjb_update_timeout,
  git_revision                => $jjb_git_revision,
  git_url                     => $jjb_git_url,
  config_dir                  => $::project_config::jenkins_job_builder_config_dir,
  require                     => $::project_config::config_dir,
}

# directory for ci infra scripts
file { '/opt/ci-tools/':
  ensure => 'directory',
  owner  => 'jenkins',
  group  => 'jenkins',
  mode   => '0755',
}