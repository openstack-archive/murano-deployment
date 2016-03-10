$jenkins_hash            = hiera_hash('jenkins', {})
$project_config_hash     = hiera_hash('project_config', {})
$custom_config_hash      = hiera_hash('custom_config', {})
$git_source_hash         = hiera_hash('git_source', {})

$jenkins_job_hash        = pick($jenkins_hash['jobs'], {})
$jenkins_ssl_hash        = pick($jenkins_hash['ssl'], {})
$jenkins_ssh_hash        = pick($jenkins_hash['ssh'], {})

$vhost_name              = pick_default($jenkins_hash['vhost'], hiera('hostname'), $::fqdn)
$server_admin            = pick_default($jenkins_hash['email'], hiera('admin_email'), "webmaster@${vhost_name}")
$logo                    = pick_default($jenkins_hash['logo'], '')

$jenkins_username        = pick_default($jenkins_hash['user'], 'jenkins')
$jenkins_password        = pick_default($jenkins_hash['password'], '')

$ssl_cert                = pick_default($jenkins_ssl_hash['cert'], '/etc/ssl/certs/ssl-cert-snakeoil.pem')
$ssl_key                 = pick_default($jenkins_ssl_hash['key'], '/etc/ssl/private/ssl-cert-snakeoil.key')
$ssl_chain               = pick_default($jenkins_ssl_hash['chain'], '')

$ssh_private_key         = pick_default($jenkins_ssh_hash['private_key'], '')
$ssh_public_key          = pick_default($jenkins_ssh_hash['public_key'], '')

$jenkins_job_builder     = pick($git_source_hash['jenkins_job_buidler'], {})

$manage_jenkins_jobs     = pick_default($jenkins_job_hash['manage'], false)
$jenkins_url             = pick_default($jenkins_job_hash['jenkins_url'], "http://127.0.0.1:8080")
$jjb_update_timeout      = 1200
$jjb_git_url             = pick($jenkins_job_builder['repository'], 'https://git.openstack.org/openstack-infra/jenkins-job-builder')
$jjb_git_revision        = pick($jenkins_job_builder['revision'], 'master')

$project_config_repo     = pick_default($project_config_hash['repository'], '')
$project_config_base     = pick_default($project_config_hash['base'], '')
$project_config_rev      = pick_default($project_config_hash['revision'], 'master')

#custom config if jenkins should be run under apache proxy
$use_proxy               = pick_default($custom_config_hash['jenkins_use_proxy'], false )
$default_config          = pick_default($custom_config_hash['jenkins_default_config'], "puppet:///modules/jenkins/jenkins.default" )

#if build logs should be kept locally
$builds_archive_dir      = pick_default($custom_config_hash['builds_archive_dir'], '' )
$clean_old_archives      = pick_default($custom_config_hash['clean_old_archives_cron'], false )

###

class { 'jenkins::jenkinsuser':
  ssh_key => $ssh_public_key,
  gitfullname => 'MuranoCI Jenkins',
  gitemail => 'jenkins@localhost',
  gerrituser => 'jenkins',
}

if $use_proxy == true {

  class { '::jenkins::master':
    vhost_name              => $vhost_name,
    serveradmin             => $server_admin,
    logo                    => $logo,
    ssl_cert_file           => $ssl_cert,
    ssl_key_file            => $ssl_key,
    ssl_chain_file          => $ssl_chain,
    jenkins_ssh_private_key => $ssh_private_key,
    jenkins_ssh_public_key  => $ssh_public_key,
    jenkins_default         => $default_config,
  }

  file { '/etc/apache2/conf-enabled/jenkins.conf':
    ensure  => file,
    source  => "puppet:///modules/muranoci-extras/jenkins.conf",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Class['Jenkins::Master'],
    notify  => Service['httpd'],
  }
} else {

  class { '::jenkins::master':
    vhost_name              => $vhost_name,
    serveradmin             => $server_admin,
    logo                    => $logo,
    ssl_cert_file           => $ssl_cert,
    ssl_key_file            => $ssl_key,
    ssl_chain_file          => $ssl_chain,
    jenkins_ssh_private_key => $ssh_private_key,
    jenkins_ssh_public_key  => $ssh_public_key,
  }
}

Class['Jenkins::Jenkinsuser'] -> Class['Jenkins::Master']

jenkins::plugin { 'build-timeout':
  version => '1.14',
}

jenkins::plugin { 'copyartifact':
  version => '1.22',
}

jenkins::plugin { 'dashboard-view':
  version => '2.3',
}

jenkins::plugin { 'gearman-plugin':
  version => '0.1.1',
}

jenkins::plugin { 'git':
  version => '1.1.23',
}

jenkins::plugin { 'greenballs':
  version => '1.12',
}

jenkins::plugin { 'extended-read-permission':
  version => '1.0',
}

jenkins::plugin { 'zmq-event-publisher':
  version => '0.0.3',
}

jenkins::plugin { 'scp':
  version    => '1.9',
  plugin_url => 'http://tarballs.openstack.org/ci/scp.jpi',
}

jenkins::plugin { 'jobConfigHistory':
  version => '1.13',
}

jenkins::plugin { 'monitoring':
  version => '1.40.0',
}

jenkins::plugin { 'nodelabelparameter':
  version => '1.2.1',
}

jenkins::plugin { 'notification':
  version => '1.4',
}

jenkins::plugin { 'openid':
  version => '1.5',
}

jenkins::plugin { 'postbuildscript':
  version => '0.16',
}

jenkins::plugin { 'publish-over-ftp':
  version => '1.7',
}

jenkins::plugin { 'simple-theme-plugin':
  version => '0.2',
}

jenkins::plugin { 'timestamper':
  version => '1.3.1',
}

jenkins::plugin { 'token-macro':
  version => '1.5.1',
}

jenkins::plugin { 'envinject':
  version => '1.92.1',
}

jenkins::plugin { 'rebuild':
  version => '1.25',
}


if $manage_jenkins_jobs == true {
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

}

file { '/home/jenkins/.ssh/id_rsa':
  ensure  => 'file',
  owner   => 'jenkins',
  group   => 'jenkins',
  mode    => '0600',
  content => $ssh_private_key,
  require => File['/home/jenkins/.ssh'],
}

if $builds_archive_dir {

  file { "${builds_archive_dir}":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0755',
  }

  if $clean_old_archives {

    cron { builds_logs_cleanup:
      command => "find ${builds_archive_dir}/* -mindepth 1 -maxdepth 2 -type d -ctime +7 -exec rm -rf {} \;",
      user     => root,
      hour     => 0,
      minute   => 0,
      monthday => [14, 28],
      ensure   => present,
    }
  }
}
