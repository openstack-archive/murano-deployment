#!/bin/sh
# Agent config file encoded by murano-conductor
service murano-agent stop

AgentConfigBase64='%AGENT_CONFIG_BASE64%'
echo $AgentConfigBase64 | base64 -d > /etc/murano-agent.conf

# CA-certificate base64 encoded by murano-conductor
if [ -n "%CA_ROOT_CERT_BASE64%" ]; then
 cat >>/etc/cacert.base64<<"EOF"
%CA_ROOT_CERT_BASE64%
EOF
 cat /etc/cacert.base64 | base64 -d > /etc/cacert.pem
 sed -i 's/ca_certs.*=/ca_certs=\/etc\/cacert.pem/' /etc/murano-agent.conf
 chmod 644 /etc/cacert.pem

 rm /etc/cacert.base64
fi

service murano-agent start
