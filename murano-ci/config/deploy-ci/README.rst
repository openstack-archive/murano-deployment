MURANO-CI
==========

'deploy.sh' is script for simple installation and configuration zuul, jenkins, nodepool for murano-ci. Default parameters of script are enough to deploy environment, but zuul'll not work without right private key. So, if you want to use voting zuul you need:

.. sourcecode:: bash

    export zuul_ssh_private_key_contents=$(cat your_gerrit_ssh_private_key)`

Then you need to configure nodepool.yaml for your ci. Our nodepool.yaml contains defaults for murano-ci. For your CI you should edit 'murano-ci/config/deploy-ci/config/modules/openstack_project/templates/nodepool/nodepool.yaml.erb' as you need (paste your credentials: username, password, auth-url, project-id; change count of servers, image name, min-ram and etc).

Then you are ready to run script 'deploy.sh':

.. sourcecode:: bash

    sudo bash deploy.sh -sysadmins your@mail.com -host_ip public_host_ip

First of all, this script will install jenkins on your host. Then you should enter parameters (they will be asked on input). They are:

1. jenkins-credentials-id

2. jenkins-api-user

3. jenkins-api-key

1, 2 and 3 you should setup on jenkins UI. Use help message.

4. network manager (neutron or nova)

5. if your network is neutron, you should enter id of private network and name of public ip pool.

If you set 'neutron' you should also specify network id and public ip pool. It'll be asked to input.

At the end you will get ready to use environment with nodepool, jenkins and zuul.


If you want to change defaults that are set in script, you should set variables (use 'export'):

1. jenkins_ssh_private_key_contents=$(cat ~/.ssh/your_id_rsa) - as default we create a keypair

2. nodepool_mysql_password - default is 'nodepool_sql'

3. nodepool_mysql_root_password - default is 'nodepool_sql'

4. nodepool_ssh_private_key_contents - default is '$jenkins_ssh_private_key_contents'

5. zuul_ssh_private_key_contents - default is '$jenkins_ssh_private_key_contents'

6. nodepool_ssh_public_key_contents - default is created public key

7. user - name for new sudoer user on your host for installation (default is ci)

8. user_pub_key - default is created private key
