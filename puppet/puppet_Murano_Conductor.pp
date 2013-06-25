# TODO:
#   1. tnurlygayanov: Fix issue with configuration files (like in OpenStack projects)
#   2. tnurlygayanov: Fix issue with installation from git repository.
#      Now we are use ./setup.sh script from git repository.
#      Need to track all installation actions from puppet recepies

class murano::conductor (
    $rabbit_vhost = 'murano',
    $rabbit_user = 'murano',
    $rabbit_password = 'murano',
    $rabbit_host = '127.0.0.1',
    $keystone_url = 'http://127.0.0.1:5000/v2.0'
) {
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
        provider             => 'rabbitmqctl',
    }

    vcsrepo { '/tmp/murano-conductor':
        ensure   => present,
        provider => git,
        source   => 'git://github.com/stackforge/murano-conductor.git',
        revision => 'release-0.1',
        alias    => 'step1';
    }

    exec {'Install new version':
        require  => Vcsrepo['step1'],
        command  => 'git checkout release-0.1; chmod +x setup.sh; ./setup.sh purge-init; ./setup.sh install',
        user     => 'root',
        provider => shell,
        cwd      => '/tmp/murano-conductor',
        alias    => 'step2';
    }

    exec {'Copy configuration files':
        require  => Exec['step2'],
        command  => 'cp conductor.conf.sample conductor.conf',
        user     => 'root',
        provider => shell,
        cwd      => '/etc/murano-conductor',
        path     => '/bin',
        alias    => 'step3';
    }

    ini_setting {'Modify RabbitMQ vhost in configuration file':
        before   => Service["murano-conductor"],
        require  => Exec['step3'],
        path     => '/etc/murano-conductor/conductor.conf',
        section  => 'rabbitmq',
        setting  => 'virtual_host',
        value    => "$rabbit_vhost",
        ensure   => present;
    }

    ini_setting {'Modify RabbitMQ user in configuration file':
        before   => Service["murano-conductor"],
        require  => Exec['step3'],
        path     => '/etc/murano-conductor/conductor.conf',
        section  => 'rabbitmq',
        setting  => 'login',
        value    => "$rabbit_user",
        ensure   => present;
    }

    ini_setting {'Modify RabbitMQ password in configuration file':
        before   => Service["murano-conductor"],
        require  => Exec['step3'],
        path     => '/etc/murano-conductor/conductor.conf',
        section  => 'rabbitmq',
        setting  => 'password',
        value    => "$rabbit_password",
        ensure   => present;
    }

    ini_setting {'Modify RabbitMQ host IP in configuration file':
        before   => Service["murano-conductor"],
        require  => Exec['step3'],
        path     => '/etc/murano-conductor/conductor.conf',
        section  => 'rabbitmq',
        setting  => 'host',
        value    => "$rabbit_host",
        ensure   => present;
    }

    ini_setting {'Modify Keystone auth url in configuration file':
        before   => Service["murano-conductor"],
        require  => Exec['step3'],
        path     => '/etc/murano-conductor/conductor.conf',
        section  => 'heat',
        setting  => 'auth_url',
        value    => "$keystone_url",
        ensure   => present;
    }

    service {'murano-conductor':
        ensure     => running,
        hasrestart => true,
        hasstatus  => true;
    }
}