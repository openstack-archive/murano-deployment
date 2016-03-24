HOW-TO deploy Murano single node CI infrastructure
##################################################

Prepare your hardware (or vm) and install Ubuntu Server 14.04 x86_64.

As 'root' prepare your host:

.. code-block:: console

	# apt-get update
	# apt-get install git
	# git clone https://github.com/openstack/murano-deployment /opt/murano-deployment
	# cd /opt/murano-deployment/murano-ci/config/puppet-ci/hiera/etc
..

Edit config.yaml, globals.yaml, users.yaml as required for your environment.

Run deploy using deploy.sh script located in /opt/murano-deployment/murano-ci/config/puppet-ci:

.. code-block:: console

	# cd /opt/murano-deployment/murano-ci/puppet-ci
	# ./deploy.sh

..

When done, restart CI services:

.. code-block:: console

	#service zuul start
	#service zuul-merger start
	#service jenkins restart
..

Configure Jenkins authentication and other settings via web interface
(more info http://docs.openstack.org/infra/system-config/jenkins.html)
and accordingly edit fields in /etc/hiera/config.yaml. Change next fields:

	::

		jenkins:
			user: "JENKINS_ADMIN_USERNAME"
 			password: "JENKINS_ADMIN_TOKEN"

		nodepool:
			jenkins:
				user: "JENKINS_ADMIN_USERNAME"
				apikey: "JENKINS_ADMIN_TOKEN"
				credentials: "JENKINS_SSH_CREDENTIALS_ID"

Apply jenkins_jobs.pp in order to install jenkins jobs builder
and upload jobs config to jenkins:

.. code-block:: console

	#cd /opt/murano-deployment/murano-ci/puppet-ci
	#puppet apply -vd manifests/jenkins_jobs.pp
..

And Nodepool configuration:

.. code-block:: console

	#cd /opt/murano-deployment/murano-ci/puppet-ci
	#puppet apply -vd manifests/nodepool.pp
..

Edit /etc/nodepool/nodepool.yaml as needed for your environment and start nodepool service:

.. code-block:: console

	#service nodepool start
..
