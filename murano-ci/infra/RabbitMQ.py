#  Licensed under the Apache License, Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License. You may obtain
#  a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.

from pyrabbit import api
import argparse
import sys
import time
# Global variables and command line parsing
parser = argparse.ArgumentParser(description="Script for creating rabbitmq"
                                             "users and vhost for jenkins's"
                                             "jobs")
parser.add_argument('-rabbitmq_host', dest='rabbitmq_host', type=str,
                    help='Host of RabbitMQ', default='localhost')
parser.add_argument('-rabbitmq_port', dest='rabbitmq_port', type=str,
                    help="Management port of RabbitMQ", default='55672')
parser.add_argument('-rabbitmq_username', dest='rabbitmq_username', type=str,
                    help='Username for RabbitMQ auth', default='guest')
parser.add_argument('-rabbitmq_password', dest='rabbitmq_password', type=str,
                    help='Password for RabbitMQ auth', default='guest')
parser.add_argument('-username', dest='username', type=str,
                    help="Username", default='test')
parser.add_argument('-password', dest='password', type=str,
                    help='Password', default='swordfish')
parser.add_argument('-vhostname', dest='vhostname', type=str,
                    help='Vhost name', default='test')
parser.add_argument('-action', dest='action', type=str,
                    help='create/delete', default='create')
args = parser.parse_args()
rabbitmq_host = args.rabbitmq_host
rabbitmq_port = args.rabbitmq_port
rabbitmq_url = str(rabbitmq_host + ":" + rabbitmq_port)
rabbitmq_user = args.rabbitmq_username
rabbitmq_password = args.rabbitmq_password
user = args.username
password = args.password
vhost = args.vhostname
action = args.action
#
# Functions
#


class DevNull(object):
    def write(self, data):
        pass


# suppress console output
_stdout = None


def mute_stdout():
    global _stdout
    if _stdout is None:
        _stdout = sys.stdout
        sys.stdout = DevNull()


# restore console output
def unmute_stdout():
    global _stdout
    if _stdout is not None:
        sys.stdout = _stdout
        _stdout = None


# check rabbitmq connection state
def check_connection():
    try:
        cl.is_alive()
    except Exception, err:
        msg = "Can't connect to '{0}'"
        print(msg.format(rabbitmq_url))
        exit(1)
    return True


# check management context port
def check_mgmt_ctx_port():
    global rabbitmq_url
    global cl
    try:
        overview = cl.get_overview()
        ctx_port = str(overview['contexts'][0]['port'])
        rabbitmq_url = str(rabbitmq_host + ":" + ctx_port)
        cl = api.Client(rabbitmq_url, rabbitmq_user, rabbitmq_password)
    except Exception, err:
        print(err)
        exit(1)
    check_connection()


# check vhost existence
def check_vhost_exists(vhost_name):
    try:
        mute_stdout()
        cl.get_vhost(vhost)
    except Exception, err:
        unmute_stdout()
        if err.status == 404:
            msg = "There is no vhost named '{0}'"
            print(msg.format(vhost_name))
            return False
    unmute_stdout()
    return True


# queues cleanup
def clean_queues(vhost_name):
    owner = api.Client(rabbitmq_url, user, password)
    try:
        vhost_queues = owner.get_queues(vhost_name)
    except:
        msg = ("Something wrong with credentials, "
               "can't access queues in the vhost '{0}'")
        print(msg.format(vhost_name))
        return
    if vhost_queues.count > 0:
        for vhost_queue in vhost_queues:
            try:
                owner.purge_queue(vhost_name, vhost_queue['name'])
            except Exception, err:
                msg = "Purge queue '{0}' from vhost '{1}' fails"
                print(msg.format(vhost_queue['name'], vhost_name))
            try:
                owner.delete_queue(vhost_name, vhost_queue['name'])
            except Exception, err:
                msg = "Delete queue '{0}' from vhost '{1}' fails"
                print(msg.format(vhost_queue['name'], vhost_name))
    else:
        msg = "Queues absent in vhost '{0}'"
        print(vhost_name)


# remove rabbitmq endpoint
def remove_rabbit_endpoint(vhost_name, vhost_owner):
    retries = 2
    ret_interval = 2
    print("Deleting vhost '%s' and user '%s'" % (vhost_name, vhost_owner))
    for attempt in range(retries):
        try:
            mute_stdout()
            cl.delete_user(vhost_owner)
        except Exception, err:
            unmute_stdout()
            msg = ("User '{0}' deletion fails or user doesn't exists,"
                   " making one more attempt '{1}'")
            print(msg.format(vhost_owner, attempt + 1))
            time.sleep(ret_interval)
        else:
            unmute_stdout()
            msg = "...user '{0}' deleted"
            print(msg.format(vhost_owner))
            break
    for attempt in range(retries):
        try:
            cl.delete_vhost(vhost_name)
        except Exception, err:
            unmute_stdout()
            msg = "Error occurred: '{0}', making one more attempt '{1}'"
            print(msg.format(err, attempt + 1))
            time.sleep(ret_interval)
        else:
            unmute_stdout()
            msg = "...vhost '{0}' deleted"
            print(msg.format(vhost_name))
            break
    else:
        msg = "Vhost '{0}' deletion fails, max attempts reached"
        print(msg.format(vhost_name))
        exit(1)


# add rabbitmq endpoint
def create_rabbit_endpoint(vhost_name, vhost_owner, vhost_password):
    retries = 4
    ret_interval = 2
    msg = "Creating vhost '{0}' and user '{1}'"
    print(msg.format(vhost_name, vhost_owner))
    for attempt in range(retries):
        try:
            cl.create_vhost(vhost_name)
        except Exception, err:
            msg = "Error occurred: '{0}', making one more attempt '{1}'"
            print(msg.format(err, attempt + 1))
            time.sleep(ret_interval)
        else:
            print("...vhost created")
            break
    for attempt in range(retries):
        try:
            cl.create_user(vhost_owner, vhost_password, tags='administrator')
        except Exception, err:
            msg = "Error occurred: '{0}', making one more attempt '{1}'"
            print(msg.format(err, attempt + 1))
            time.sleep(ret_interval)
        else:
            print("...username and password set")
            break
    for attempt in range(retries):
        try:
            cl.set_vhost_permissions(vhost_name, vhost_owner, '.*', '.*', '.*')
        except Exception, err:
            msg = "Error occurred: '{0}', making one more attempt '{1}'"
            print(msg.format(err, attempt + 1))
            time.sleep(ret_interval)
        else:
            print("...permissions set")
            break
    else:
        print("Max attempts reached, exiting!")
        exit(1)


# Main runtime
print("-" * 30)
print("This script will configure RabbitMQ server for Murano."
      "If something can't be deleted, probably it doesn't exist.")
cl = api.Client(rabbitmq_url, rabbitmq_user, rabbitmq_password)
check_connection()
check_mgmt_ctx_port()
if check_vhost_exists(vhost):
    print("vhost named '%s' exists and will be deleted" % vhost)
    clean_queues(vhost)
    remove_rabbit_endpoint(vhost, user)
if action == 'create':
    create_rabbit_endpoint(vhost, user, password)
print("-" * 30)
exit(0)
