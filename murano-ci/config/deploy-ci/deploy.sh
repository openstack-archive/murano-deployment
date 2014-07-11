#!/bin/bash
#
gerrit_private_key=/opt/gerrit
if [ ! -f "$gerrit_private_key" ] ;then
   echo "Save you gerrit private key as \"$gerrit_private_key\"!"
   exit 1
fi
export zuul_ssh_private_key_contents=$(cat $gerrit_private_key)
set -e

# You need to use 12.04 Ubuntu as your host OS

SAVANNA_CI_CONFIG_REPO=${SAVANNA_CI_CONFIG_REPO:-"$(pwd)/config"}

function help_message ()
{
  echo "
##############################################
# If you don't want to use defaults you need #
#   to specify some parameters. See README   #
##############################################

       You need to specify:
-sysadmins    - your mail
-host_ip      - ip of the host where you run the script"
}

# function for correct writing the key to hieradata
key_string ()
{
  export key_content="-----BEGIN RSA PRIVATE KEY-----\n"
  echo "$1" > /tmp/tmp_key
  sed -i "1d" /tmp/tmp_key
  sed -i "\$d" /tmp/tmp_key
  for i in $(cat /tmp/tmp_key)
  do
    key_content="$key_content$i\n"
  done
  rm /tmp/tmp_key
  key_content="$key_content-----END RSA PRIVATE KEY-----"
  echo $key_content
}
# Commandline arguments
while true ; do
  case "$1" in
    -sysadmins) export sysadmins=$2; shift 2 ;;
    -host_ip) export ip=$2; shift 2 ;;
    -h | --help) help_message; exit 0 ;;
    *) if [ -z "$sysadmins" ] || [ -z "$ip" ]; then
         echo "Miss options"
         help_message
         exit 1
       else break
       fi
       ;;
  esac
done

export nodepool_mysql_password=${nodepool_mysql_password:-"nodepool_sql"}
export nodepool_mysql_root_password=${nodepool_mysql_root_password:-"nodepool_sql"}
echo "mysql-server-5.5 mysql-server/root_password password $nodepool_mysql_root_password" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $nodepool_mysql_root_password" | debconf-set-selections

apt-get update
apt-get upgrade -y
apt-get install python-pip python-setuptools git mysql-server libmysqlclient-dev g++ python-dev libzmq-dev maven gcc -y

# Fix problem with python-setuptools: 'No module named pkg_resources'
#curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py | sudo python

# Jenkins Jobs copy
git clone https://github.com/stackforge/murano-deployment /opt/muranodep
mkdir -p $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/jenkins_job_builder/config/
cp /opt/muranodep/murano-ci/jobs/* $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/jenkins_job_builder/config/
mkdir -p /opt/ci/jenkins-jobs/
cp $SAVANNA_CI_CONFIG_REPO/../files/update_jobs.sh /opt/ci/jenkins-jobs/update_jobs.sh
chmod +x /opt/ci/jenkins-jobs/update_jobs.sh
#cp /opt/savanna-ci/config/zuul/layout.yaml $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/zuul/
rm -rf /opt/muranodep

# Running infra scripts
git clone https://github.com/openstack-infra/config /opt/config
bash /opt/config/install_puppet.sh
bash /opt/config/install_modules.sh
rm -rf /opt/config

if [ -z "$jenkins_ssh_private_key_contents" ]; then
  # Generating key for jenkins
  ssh-keygen -t rsa -P "" -N "" -f ~/.ssh/id_rsa
  export jenkins_ssh_private_key_contents=$(cat ~/.ssh/id_rsa)
fi

jenkins_ssh_private_key_contents=$(key_string "$jenkins_ssh_private_key_contents")

# Setup hiera data dir
mkdir -p /etc/puppet/hieradata/production/
cat > /etc/puppet/hiera.yaml<<EOF
---
:hierarchy:
  - %{operatingsystem}
  - common
:backends:
  - yaml
:yaml:
  :datadir: '/etc/puppet/hieradata/%{environment}'
EOF

#echo "Enter local jenkins plugin dir:"
#read line
export jenkins_plugin_local_dir=$SAVANNA_CI_CONFIG_REPO/../files/

export node=$(hostname)
export jenkins_jobs_password=${jenkins_jobs_password:-admin}
# Add parameters for puppet scripts
cat > /etc/puppet/hieradata/production/common.yaml<<EOF
sysadmins: ['$sysadmins']
jenkins_jobs_password: "$jenkins_jobs_password"
jenkins_ssh_private_key_contents: "$jenkins_ssh_private_key_contents"
zmq_event_receivers: ['$node']
plugin_dir: "$jenkins_plugin_local_dir"
EOF

apt-get install hiera-puppet -y

if [ -e $SAVANNA_CI_CONFIG_REPO/manifests/ ]; then
  rm -rf $SAVANNA_CI_CONFIG_REPO/manifests/
fi

mkdir $SAVANNA_CI_CONFIG_REPO/manifests/

cat > $SAVANNA_CI_CONFIG_REPO/manifests/site.pp<<EOF
node default {
  include openstack_project::puppet_cron
  class { 'openstack_project::server':
    sysadmins => hiera('sysadmins'),
  }
}

node $node {
  class { 'openstack_project::jenkins':
    jenkins_jobs_password   => hiera('jenkins_jobs_password'),
    jenkins_ssh_private_key => hiera('jenkins_ssh_private_key_contents'),
    jenkins_ssh_public_key  => '$(ssh-keygen -y -f ~/.ssh/id_rsa)',
    sysadmins               => hiera('sysadmins'),
    zmq_event_receivers     => hiera('zmq_event_receivers'),
    plugin_dir              => hiera('plugin_dir'),
  }
}
EOF

export user=${user:-ci}
sed -i "s%      User::Virtual::Localuser\['.*'\],%      User::Virtual::Localuser\['$user'\],%g" $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/manifests/base.pp

cat > $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/manifests/users.pp <<EOF
class openstack_project::users {
  @user::virtual::localuser { '$user':
    realname => '$user',
    sshkeys  => "$user_pub_key\n",
  }
}
EOF

pip install --upgrade pip==1.4.1
pip install --upgrade six

puppet apply --modulepath="$SAVANNA_CI_CONFIG_REPO/modules:/etc/puppet/modules" $SAVANNA_CI_CONFIG_REPO/manifests/site.pp

iptables -F
chown -R jenkins:jenkins /opt/ci/jenkins-jobs/

echo -e "
##########################################################
#           Jenkins is succesfully installed.            #
#     Using jenkins UI you should create credentials.    #
# Credentials should be 'SSH Username with private key'. #
#      Specify username as 'jenkins' and Private key     #
#              from a file on Jenkins master             #
#    (specify full path: '/home/jenkins/.ssh/id_rsa').   #
##########################################################

Enter parameters:"
echo "Enter jenkins credentials_id"
read line
export jenkins_credentials_id=$line
echo "Enter jenkins api username"
read line
export jenkins_api_user=$line
echo "Enter jenkins api-token"
read line
export jenkins_api_key=$line
export jenkins_jobs_password=$line
echo "Enter network type (neutron or nova)"
read line
export network=$line
#
echo "Enter CI lab ip address"
read line
export lab_ip=$line
echo "Enter CI tenant name"
read line
export lab_tenant=$line
echo "Enter CI tenant username"
read line
export lab_user=$line
echo "Enter CI tenant user password"
read line
export lab_password=$line
#
if [ -z "$sysadmins" ] ||  [ -z "$jenkins_credentials_id" ] || [ -z "$jenkins_api_user" ] || [ -z "$jenkins_api_key" ] || [ -z "$network" ] || [ -z "$lab_ip" ] || [ -z "$lab_tenant" ] || [ -z "$lab_user" ] || [ -z "$lab_password" ]; then
  echo "Empty parameters"
  exit 1
fi


if [ $network == "neutron" ]; then
  echo "Enter private network id:"
  read line
  export net_id="- net-id: $line"
  echo "Enter public ip pool's name:"
  read line
  export ip_pool=$line
elif [ $network != "nova" ]; then
  echo "Uknown network"
  exit 1
fi

# Using one ssh_key for zuul, jenkins and nodepool as default
export nodepool_ssh_private_key_contents=${nodepool_ssh_private_key_contents:-$jenkins_ssh_private_key_contents}
export zuul_ssh_private_key_contents=${zuul_ssh_private_key_contents:-$jenkins_ssh_private_key_contents}
export jenkins_ssh_public_key_contents=${jenkins_ssh_public_key_contents:-$(ssh-keygen -y -f ~/.ssh/id_rsa)}
export nodepool_ssh_public_key_contents=${nodepool_ssh_public_key_contents:-$(ssh-keygen -y -f ~/.ssh/id_rsa)}

zuul_ssh_private_key_contents=$(key_string "$zuul_ssh_private_key_contents")
nodepool_ssh_private_key_contents=$(key_string "$nodepool_ssh_private_key_contents")

export NODEPOOL_SSH_KEY=$nodepool_ssh_public_key_contents
export STATSD_HOST='127.0.0.1'
export STATSD_PORT='8125'
export user_pub_key=${user_pub_key:-$(cat ~/.ssh/id_rsa.pub)}
export jenkins_url='http://127.0.0.1:8080'

cat > $SAVANNA_CI_CONFIG_REPO/manifests/site.pp<<EOF
node default {
  include openstack_project::puppet_cron
  class { 'openstack_project::server':
    sysadmins => hiera('sysadmins'),
  }
}

node $node {
  class { 'openstack_project::nodepool':
    mysql_password           => hiera('nodepool_mysql_password'),
    mysql_root_password      => hiera('nodepool_mysql_root_password'),
    nodepool_ssh_private_key => hiera('jenkins_ssh_private_key_contents'),
    sysadmins                => hiera('sysadmins'),
    jenkins_api_user         => hiera('jenkins_api_user'),
    jenkins_api_key          => hiera('jenkins_api_key'),
    jenkins_credentials_id   => hiera('jenkins_credentials_id'),
    jenkins_url              => '$jenkins_url',
    path_to_scripts          => '/etc/nodepool/scripts',
    ip_pool                  => '$ip_pool',
    net_id                   => '$net_id',
    lab_ip                   => '$lab_ip',
    lab_tenant               => '$lab_tenant',
    lab_user                 => '$lab_user',
    lab_password             => '$lab_password',
  }

  class { 'openstack_project::zuul_prod':
    gerrit_server        => 'review.openstack.org',
    gerrit_user          => 'murano-ci',
    zuul_ssh_private_key => hiera('zuul_ssh_private_key_contents'),
    url_pattern          => 'http://$ip/{build.parameters[LOG_PATH]}',
    zuul_url             => 'http://$ip',
    status_url           => 'http://$ip/zuul/',
    sysadmins            => hiera('sysadmins'),
    gearman_workers      => ['$node'],
  }
}
EOF

# Add parameters for puppet scripts
cat > /etc/puppet/hieradata/production/common.yaml<<EOF
sysadmins: ['$sysadmins']
nodepool_ssh_private_key: "$nodepool_ssh_private_key_contents"
nodepool_mysql_password: "$nodepool_mysql_password"
nodepool_mysql_root_password: "$nodepool_mysql_root_password"
zuul_ssh_private_key_contents: "$zuul_ssh_private_key_contents"
jenkins_credentials_id: '$jenkins_credentials_id'
jenkins_api_user: "$jenkins_api_user"
jenkins_api_key: "$jenkins_api_key"
jenkins_jobs_password: "$jenkins_api_key"
jenkins_ssh_private_key_contents: "$jenkins_ssh_private_key_contents"
zmq_event_receivers: ['$node']
EOF

#cp $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/nodepool/scripts/prepare_node_tmp.sh $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/nodepool/scripts/prepare_node.sh
#echo -e "sudo su - jenkins -c \"echo '$jenkins_ssh_public_key_contents' >> /home/jenkins/.ssh/authorized_keys\"\nsync\nsleep 5" >> $SAVANNA_CI_CONFIG_REPO/modules/openstack_project/files/nodepool/scripts/prepare_node.sh
sudo su - jenkins -c "echo $jenkins_ssh_public_key_contents >> /home/jenkins/.ssh/authorized_keys"
puppet apply --modulepath="$SAVANNA_CI_CONFIG_REPO/modules:/etc/puppet/modules" $SAVANNA_CI_CONFIG_REPO/manifests/site.pp
mkdir /opt/logs && chown -R jenkins:jenkins /opt/logs
echo -e "sudo su - jenkins -c \"echo '$jenkins_ssh_public_key_contents' >> /home/jenkins/.ssh/authorized_keys\"\nsync\nsleep 5" >> /etc/nodepool/scripts/prepare_node.sh

su - nodepool -c 'export NODEPOOL_SSH_KEY="$NODEPOOL_SSH_KEY"'
sed -i "s%password=admin%password=$jenkins_jobs_password%g" /etc/jenkins_jobs/jenkins_jobs.ini
sed -i '/self.socket.RCVTIMEO/s/^/#/' $(pip show nodepool | grep -e 'Location:' | grep -oe "\/.*")/nodepool/nodepool.py
cd /opt/zuul/etc/status && bash fetch-dependencies.sh

#Oracle JAVA install
apt-get install python-software-properties -y
add-apt-repository -y ppa:webupd8team/java
apt-get update -y
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
apt-get -y install oracle-java8-installer 

#Stopping services
service zuul stop
service nodepool stop
service zuul-merger stop

#Uncomment for auto-start
# service zuul start
# service zuul-merger start
# service nodepool start
