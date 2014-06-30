from pyrabbit import api
import argparse
import sys
import time
# Global variables and command line parsing
parser = argparse.ArgumentParser(description="Script for creating rabbitmq"
                                             "users and vhost for jenkins's"
                                             "jobs")
parser.add_argument("-rabbitmq_host",  dest='rabbitmq_host',  type=str,
                    help="Host of RabbitMQ", default='localhost')
parser.add_argument("-rabbitmq_port",  dest='rabbitmq_port',  type=str,
                    help="Management port of RabbitMQ", default='55672')
parser.add_argument("-rabbitmq_username",  dest='rabbitmq_username',  type=str,
                    help="Username for RabbitMQ auth",  default='guest')
parser.add_argument("-rabbitmq_password",  dest='rabbitmq_password',  type=str,
                    help="Password for RabbitMQ auth",  default='guest')
parser.add_argument("-username",  dest='username',  type=str,
                    help="Username",  default='test')
parser.add_argument("-password",  dest='password',  type=str,
                    help="Password",  default='swordfish')
parser.add_argument("-vhostname",  dest='vhostname',  type=str,
                    help="Vhost name",  default='test')
parser.add_argument("-action",  dest='action',  type=str,
                    help="create/delete",  default='create')
args = parser.parse_args()
rabbitmq_host = args.rabbitmq_host
rabbitmq_port = args.rabbitmq_port
rabbitmq_url = str(rabbitmq_host+":"+rabbitmq_port)
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
    def write(self, data): pass

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
        print("Can't connect to '%s'" % rabbitmq_url)
        exit(1)
    return True

# check management context port
def check_mgmt_ctx_port():
    global rabbitmq_url
    global cl
    try:
        overview=cl.get_overview()
        rabbitmq_url=str(rabbitmq_host+":"+str(overview['contexts'][0]['port']))
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
            print("No vhost named '%s'" % vhost_name)
            return False
    unmute_stdout()
    return True

# queues cleanup
def clean_queues(vhost_name):
    owner=api.Client(rabbitmq_url, user, password)
    try:
        vhost_queues=owner.get_queues(vhost_name)
    except :
        print("Something wrong with credentials, can't access queues in the vhost '%s'" % vhost_name)
        return
    if vhost_queues.count > 0:
        for vhost_queue in vhost_queues:
            try:
                owner.purge_queue(vhost_name,vhost_queue['name'])
            except Exception, err:
                print("Purge queue '%s' from vhost '%s' fails" % (vhost_queue['name'],vhost_name))
            try:
                owner.delete_queue(vhost_name, vhost_queue['name'])
            except Exception, err:
                print("Delete queue '%s' from vhost '%s' fails" % (vhost_queue['name'],vhost_name))
    else:
        print("Queues absent in vhost '%s'" % vhost_name)

# remove rabbitmq endpoint
def remove_rabbit_endpoint(vhost_name,vhost_owner):
    print("Deleting vhost '%s' and user '%s'" % (vhost_name,vhost_owner))
    try:
        mute_stdout()
        cl.delete_user(vhost_owner)
    except Exception, err:
        unmute_stdout()
        print("User '%s' deletion fails or user doesn't exists" % vhost_owner)
    unmute_stdout()
    try:
        cl.delete_vhost(vhost_name)
    except Exception, err:
        print("Vhost '%s' deletion fails" % vhost_name)
        exit(1)

# add rabbitmq endpoint
def create_rabbit_endpoint(vhost_name, vhost_owner, vhost_password):
    print("Creating vhost '%s' and user '%s'" % (vhost_name,vhost_owner))
    try:
        cl.create_vhost(vhost_name)
        time.sleep(2)
        cl.create_user(vhost_owner, vhost_password, tags='administrator')
        time.sleep(2)
        cl.set_vhost_permissions(vhost_name, vhost_owner, '.*', '.*', '.*')
        time.sleep(2)
    except Exception, err:
        print(err)
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
    remove_rabbit_endpoint(vhost,user)
if action == 'create':
    create_rabbit_endpoint(vhost, user, password)
print("-" * 30)
exit(0)