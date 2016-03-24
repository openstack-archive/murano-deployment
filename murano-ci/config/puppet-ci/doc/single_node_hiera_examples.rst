Single node CI infrastructure hiera examples
############################################

Global configuration settings
-----------------------------

Global configuration settings should be provided in ``globals.yaml`` file.

Values from ``globals.yaml`` allows to implement:

  - NTP server on CI node. Example:

    ::

      ntp_servers: "0.cz.pool.ntp.org, 1.cz.pool.ntp.org, 2.cz.pool.ntp.org, 3.cz.pool.ntp.org"


  - DNS server (resolver) on CI node based on pdnsd server. Example:

     ::

       dns:
          dns_servers:
              OpenDNS1:
                  ip: "208.67.222.222"
                  uptest: "query"
                  timeout: 10
              OpenDNS2:
                  ip: "208.67.220.220"
                  uptest: "query"
                  timeout: 10
              GoogleDNS1:
                  ip: "8.8.8.8"
                  uptest: "exec"
                  timeout: 10
          listen_addr: "127.0.0.1"
          manage_resolvconf: "true"

    Parameters notes:

      - ``dns_servers`` - list of upstream DNS servers settings
      - ``manage_resolvconf`` - inserts pdnsd ip into head of
        ``resolv.conf``

  - Project config repository location - it is a repository containing zuul,
    nodepool configs, scripts and jenkins jobs. Example:

    ::

      project_config:
      repository: "https://github.com/openstack/murano-deployment"
      revision: "master"
      base: "murano-ci/"

  - Zuul, nodepool, jenkins jobs builder source repositories. Example:

    ::

      git_source:
        jenkins_job_builder:
            repository: "https://github.com/openstack-infra/jenkins-job-builder"
            revision: "master"
        nodepool:
            repository: "https://github.com/openstack-infra/nodepool"
            revision: "master"
        zuul:
            repository: "https://github.com/openstack-infra/zuul"
            revision: "master"

  - Zabbix agent. Example:

    ::

      monitoring:
        agent_start_agents: 2
        agent_timeout: 5
        agent_zabbix_server: "127.0.0.1"

    Parameters notes:
      - ``agent_zabbix_server`` - is ip address of your Zabbix monitoring
        server/proxy, should be changed.

  - Custom settings (workarounds) for CI services (zuul, nodepool, jenkins).
    Example:

    ::

      custom_config:
        jenkins_use_proxy: true
        jenkins_default_config: "puppet:///modules/muranoci-extras/jenkins.default"
        builds_archive_dir: "/opt/logs"
        clean_old_archives_cron: true
        custom_vhost: true

    This section needs extended description for its parameters:

      - ``jenkins_use_proxy: true`` - will setup jenkins under
        reverse proxy
      - ``jenkins_default_config: "puppet:///path/to/file"`` - allows 
        to customize jenkins config
      - ``builds_archive_dir: "/opt/logs"`` - will setup local builds archive
      - ``clean_old_archives_cron: true`` - manages builds archieve periodic
        cleanup
      - ``custom_vhost: true`` - changes zuul vhost so it can hold
        several sites

CI services configuration settings
----------------------------------

Zuul, nodepool, jenkins main settings should be provided in ``config.yaml`` file.

Full example of ``config.yaml`` is provided here_

.. _here: config_example.yaml

Jenkins parameters description:

  - ``vhost`` - in single node CI setup should be empty
  - ``user``,``password`` - jenkins admin user's username and API token,
    these credentials are used by JJB to connect to Jenkins API
  - ``jobs`` - JJB configuration, ``jenkins_url`` - sets url
    for JJB to connect to.
  - ``ssh`` - ssh keys for jenkins user

Zuul parameters description:

  - ``vhost`` - by default - Zuul apache vhost, should be set
    to CI site FQDN
  - ``zuul_url`` - url for Zuul's local git repository, should be accessible
    by Jenkins slaves
  - ``status_url`` - Zuul status url
  - ``git_email``, ``git_name`` - email and username used by Zuul to merge
    changes in local git repository
  - ``gerrit`` - section with review site name and gerrit user credentials

Nodepool parameters description:

  - ``vhost`` - in single node CI setup should be empty
  - ``private_key`` - nodepool key used for nodes management
  - ``jenkins`` - settings needed for nodepool connection to Jenkins API.