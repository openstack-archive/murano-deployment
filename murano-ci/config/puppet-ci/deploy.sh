#!/bin/bash

set -xe

pushd $(dirname $(readlink -f $0))

WORKSPACE=$(pwd)

apt-get install -y -q puppet-common git
gem install --no-ri --no-rdoc r10k
r10k puppetfile install Puppetfile

mkdir -p /etc/hiera
cp -Rv ${WORKSPACE}/hiera/hiera.yaml /etc/puppet/hiera.yaml
cp -Rv ${WORKSPACE}/hiera/etc/*.yaml /etc/hiera/
cp -Rv ${WORKSPACE}/modules/* /etc/puppet/modules/

puppet apply -vd manifests/users.pp
puppet apply -vd manifests/ssh.pp
puppet apply -vd manifests/dns.pp
puppet apply -vd manifests/ntp.pp

#Only jenkins and zuul are configured by this script,
#nodepool and JJB requires additional manual configuration of
#jenkins
puppet apply -vd manifests/jenkins.pp
puppet apply -vd manifests/zuul.pp

popd
