# TODO:
#   1. tnurlygayanov: Fix issue with configuration files (like in OpenStack projects)
#   2. tnurlygayanov: Fix issue with installation from git repository.
#      Now we are use ./setup.sh script from git repository.
#      Need to track all installation actions from puppet recepies

class murano::dashboard (
    $branch = 'master'
) {

    vcsrepo { '/tmp/murano-dashboard':
        ensure   => present,
        provider => git,
        source   => 'git://github.com/stackforge/murano-dashboard.git',
        revision => $branch,
        alias    => 'step1',
    }

    case  $operatingsystem {
        centos: { $cmd = "sh setup-centos.sh install" }
        default: { $cmd = "sh setup.sh install" }
    }

    exec {'Install new version':
        require  => Vcsrepo['step1'],
        command  => $cmd,
        user     => 'root',
        provider => shell,
        cwd      => '/tmp/murano-dashboard',
    }

}

class { 'murano::dashboard': }

