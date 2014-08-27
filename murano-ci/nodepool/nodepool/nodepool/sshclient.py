#!/usr/bin/env python

# Update the base image that is used for devstack VMs.

# Copyright (C) 2011-2012 OpenStack LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

import paramiko


class SSHClient(object):
    def __init__(self, ip, username, password=None, pkey=None,
                 key_filename=None, log=None):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.WarningPolicy())
        client.connect(ip, username=username, password=password, pkey=pkey,
                       key_filename=key_filename)
        self.client = client
        self.log = log

    def ssh(self, action, command, get_pty=True, output=False):
        if self.log:
            self.log.info(command)
        stdin, stdout, stderr = self.client.exec_command(
            command, get_pty=get_pty)
        out = ''
        for line in stdout:
            if output:
                out += line
            if self.log:
                self.log.info(line.rstrip())
        for line in stderr:
            if self.log:
                self.log.error(line.rstrip())
        ret = stdout.channel.recv_exit_status()
        if ret:
            raise Exception("Unable to %s" % action)
        return out

    def scp(self, source, dest):
        if self.log:
            self.log.info("Copy %s -> %s" % (source, dest))
        ftp = self.client.open_sftp()
        ftp.put(source, dest)
        ftp.close()
