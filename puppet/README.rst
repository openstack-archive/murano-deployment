Puppet recepies for Murano components
==================

How to install Murano using Puppet recepies?

Need to perform the following commands:

 apt-get install -y git puppet rabbitmq-server
 
 mkdir -p ~/.puppet/modules
 
 puppet module install puppetlabs/vcsrepo
 
 puppet module install puppetlabs/rabbitmq
 
 puppet module install puppetlabs/inifile
 
 git clone https://github.com/stackforge/murano-deployment
 
 cd murano-deployment/puppet


After that need to edit recepies (to change default values of parameters) and apply recepies:

 puppet apply puppet_Murano_REST_API.pp

 puppet apply puppet_Murano_Conductor.pp

 puppet apply puppet_Murano_Dashboard.pp


SEE ALSO
========
* `Murano <http://murano.mirantis.com>`__

