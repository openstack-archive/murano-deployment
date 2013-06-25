# TODO:
#   1. tnurlygayanov: Fix issue with configuration files (like in OpenStack projects)
#   2. tnurlygayanov: Fix issue with installation from git repository.
#      Now we are use ./setup.sh script from git repository.
#      Need to track all installation actions from puppet recepies
#   3. tnurlygayanov: Action to create new database in SQL

class murano::api (
    $rabbit_vhost               = 'murano',
	$rabbit_user                = 'murano',
	$rabbit_password            = 'murano',
	$rabbit_host                = '127.0.0.1',
	$keystone_host              = '127.0.0.1',
	$keystone_admin_user        = 'admin',
	$keystone_admin_user_token  = 'service',
	$keystone_admin_password    = 'admin_password',
	$db_type                    = 'mysql',
	$murano_db_user             = 'murano',
	$murano_db_password         = 'murano',
	$murano_db_dbname           = 'murano',
	$db_host                    = 'localhost'
) {

    case $db_type {
		'mysql': {
			$sql_connection = "mysql://${murano_db_user}:${murano_db_password}@${db_host}/${murano_db_dbname}"
		}
	}

	rabbitmq_user { "$rabbit_user":
		admin    => true,
		password => "$rabbit_password",
		provider => 'rabbitmqctl';
	}

	rabbitmq_vhost { "$rabbit_vhost":
		ensure   => present,
		provider => 'rabbitmqctl';
	}

	rabbitmq_user_permissions { "$rabbit_user@$rabbit_vhost":
		configure_permission => '.*',
		read_permission      => '.*',
		write_permission     => '.*',
		provider             => 'rabbitmqctl';
	}

    vcsrepo { '/tmp/murano-api':
        ensure   => present,
        provider => git,
        source   => 'git://github.com/stackforge/murano-api.git',
        revision => 'release-0.1',
        alias    => 'step1';
    }

	exec {'Install new version':
		require  => Exec['step1'],
		command  => 'git checkout release-0.1; chmod +x setup.sh; ./setup.sh purge-init; ./setup.sh install',
		user     => 'root',
		provider => shell,
		cwd      => '/tmp/murano-api',
		alias    => 'step2';
	}

	exec {'Copy configuration files - murano-api.conf.sample':
		require  => Exec['step2'],
		command  => 'cp murano-api.conf.sample murano-api.conf',
		user     => 'root',
		provider => shell,
		cwd      => '/etc/murano-api',
		path     => '/bin',
		alias    => 'step3.1';
	}

	exec {'Copy configuration files - murano-api-paste.ini.sample':
		require  => Exec['step2'],
		command  => 'cp murano-api-paste.ini.sample murano-api-paste.ini',
		user     => 'root',
		provider => shell,
		cwd      => '/etc/murano-api',
		path     => '/bin',
		alias    => 'step3.2';
	}

	ini_setting {'Modify RabbitMQ vhost in configuration file':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'rabbitmq',
		setting  => 'virtual_host',
		value    => "$rabbit_vhost",
		ensure   => present;
	}

	ini_setting {'Modify RabbitMQ user in configuration file':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'rabbitmq',
		setting  => 'login',
		value    => "$rabbit_user",
		ensure   => present;
	}

	ini_setting {'Modify RabbitMQ password in configuration file':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'rabbitmq',
		setting  => 'password',
		value    => "$rabbit_password",
		ensure   => present;
	}

	ini_setting {'Modify RabbitMQ host IP in configuration file':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'rabbitmq',
		setting  => 'host',
		value    => "$rabbit_host",
		ensure   => present;
	}

	ini_setting {'Logging disabled':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'DEFAULT',
		setting  => 'debug',
		value    => "False",
		ensure   => present;
	}

	ini_setting {'Change log file location settings':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'DEFAULT',
		setting  => 'log_file',
		value    => "/var/log/murano-api.log",
		ensure   => present;
	}

	ini_setting {'Set SQL connection string':
		before  => Service["murano-api"],
		require  => Exec['step3.1'],
		path     => '/etc/murano-api/murano-api.conf',
		section  => 'DEFAULT',
		setting  => 'sql_connection',
		value    => "$sql_connection",
		ensure   => present;
	}

    ini_setting {'Set Keystone Authentication host':
	    before  => Service["murano-api"],
		require  => Exec['step3.2'],
		path     => '/etc/murano-api/murano-api-paste.ini',
		section  => 'filter:authtoken',
		setting  => 'auth_host',
		value    => "$keystone_host",
		ensure   => present;
	}

	ini_setting {'Set Keystone Authentication user name':
		before  => Service["murano-api"],
		require  => Exec['step3.2'],
		path     => '/etc/murano-api/murano-api-paste.ini',
		section  => 'filter:authtoken',
		setting  => 'admin_user',
		value    => "$keystone_admin_user",
		ensure   => present;
	}

	ini_setting {'Set Keystone Authentication user password':
		before  => Service["murano-api"],
		require  => Exec['step3.2'],
		path     => '/etc/murano-api/murano-api-paste.ini',
		section  => 'filter:authtoken',
		setting  => 'admin_password',
		value    => "$keystone_admin_password",
		ensure   => present;
	}

	ini_setting {'Set Keystone Authentication service token':
		before  => Service["murano-api"],
		require  => Exec['step3.2'],
		path     => '/etc/murano-api/murano-api-paste.ini',
		section  => 'filter:authtoken',
		setting  => 'admin_tenant_name',
		value    => "$keystone_admin_user_token",
		ensure   => present;
	}

	service {'murano-api':
		ensure     => running,
		hasrestart => true,
		hasstatus  => true;
	}
}