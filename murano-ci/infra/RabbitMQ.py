from pyrabbit.api import Client
import argparse

parser = argparse.ArgumentParser(description="Script for creating rabbitmq"
                                             "users and vhost for jenkins's"
                                             "jobs")
parser.add_argument("-rabbitmq_url",  dest='rabbitmq_url',  type=str,
                    help="URL of using RabbitMQ", default='172.18.124.203:55672')
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
rabbitmq_url = args.rabbitmq_url
rabbitmq_user = args.rabbitmq_username
rabbitmq_password = args.rabbitmq_password
user = args.username
password = args.password
vhost = args.vhostname
action = args.action

cl = Client(rabbitmq_url, rabbitmq_user, rabbitmq_password)
assert cl.is_alive()

print("-" * 30)
print("This script will configure RabbitMQ server for Murano."
      "If something can't be deleted, probably it doesn't exist.")

for queue in cl.get_queues():
    if queue['vhost'] == vhost:
        try:
            cl.purge_queue(vhost, queue['name'])
            cl.delete_queue(vhost, queue['name'])
        except:
            msg = "Can't delete queue {0} in RabbitMQ host {1}"
            print(msg.format(queue['name'], rabbitmq_url))

try:
    cl.delete_vhost(vhost)
except:
    msg = "Can't delete vhost {0} in RabbitMQ host {1}"
    print(msg.format(vhost, rabbitmq_url))

try:
    cl.delete_user(user)
except:
    msg = "Can't delete user {0} in RabbitMQ host {1}"
    print(msg.format(user, rabbitmq_url))

if action == 'create':
    try:
        cl.create_vhost(vhost)
        cl.create_user(user, password, tags='administrator')
        cl.set_vhost_permissions(vhost, user, '.*', '.*', '.*')
    except:
        print("Can't init new RabbitMQ vhost and user!")

print("-" * 30)
