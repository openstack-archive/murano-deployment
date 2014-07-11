#!/bin/bash
cd /opt/ci/jenkins-jobs
rm -rf murano-deployment
git clone https://github.com/stackforge/murano-deployment
cd murano-deployment/murano-ci
sudo jenkins-jobs update jobs
