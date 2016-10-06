# Copyright 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
import re


def set_log_url(item, job, params):
    if hasattr(item.change, 'refspec'):
        path = "%s/%s/%s/%s" % (
            params['ZUUL_CHANGE'][-2:], params['ZUUL_CHANGE'],
            params['ZUUL_PATCHSET'], params['ZUUL_PIPELINE'])
    elif hasattr(item.change, 'ref'):
        path = "%s/%s/%s" % (
            params['ZUUL_NEWREV'][:2], params['ZUUL_NEWREV'],
            params['ZUUL_PIPELINE'])
    else:
        path = params['ZUUL_PIPELINE']
    params['BASE_LOG_PATH'] = path
    params['LOG_PATH'] = path + '/%s/%s' % (job.name,
                                            params['ZUUL_UUID'][:7])


def single_use_node(item, job, params):
    set_log_url(item, job, params)
    params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'


def set_params(item, job, params):
    single_use_node(item, job, params)
    if job.name != 'gate-murano-deployment':
        # Get project name which can be different from ZUUL_PROJECT parameter
        if 'murano-client' in job.name:
            project_name = 'python-muranoclient'
        else:
            # NOTE(kzaitsev) Remove leading prefix (gate, heartbeat, etc.)
            # and distro name together with everything that follows (note
            # no '$' at the end). This should leave project's name
            result = re.search("^\w+-(?P<proj_name>.*)-(?:ubuntu|debian)",
                               job.name)
            if not result:
                raise ValueError("Couldn't parse job name {}".format(
                                 job.name))
            project_name = result.group('proj_name')
        # Set override_project parameter
        params['OVERRIDE_PROJECT'] = "openstack/%s" % project_name
        # every time we are changing murano-deployment, we need to run
        # other dependent jobs with this change to be sure they are not broken
        if params['ZUUL_PROJECT'] == 'openstack/murano-deployment':
            deployment_ref = params['ZUUL_CHANGES'].rpartition(':')[2]
            params['MURANO_DEPLOYMENT_REF'] = deployment_ref
            params['ZUUL_REF'] = params.get('ZUUL_BRANCH', 'master')
            params['ZUUL_URL'] = 'https://git.openstack.org'
            params['ZUUL_PROJECT'] = "openstack/%s" % project_name
