#!/bin/bash

function show_usage {
cat << EOF

Usage:
    ./configure-rabbitmq.sh [-b] <user> <password> <vhost>

Parameters:
    -b       - batch mode
    user     - RabbitMQ user name
    password - RabbitMQ password
    vhost    - RabbitMQ vHost

EOF
}

batch_mode='false'
case $1 in
    ''|'-h')
        show_usage
        exit
    ;;
    '-b')
        batch_mode='true'
        shift
    ;;
esac

rabbitmq_user=$1
rabbitmq_password=$2
rabbitmq_vhost=$3

if [ "$batch_mode" = 'false' ]; then
    cat << EOF

You've requested the following configuration:
* RabbitMQ User '$rabbitmq_user' with password '$rabbitmq_password'
* RabbitMQ vHost '$rabbitmq_vhost'

Please confirm that it is what you want.

EOF

    confirmtion=''
    while [ "$confirmation" = '' ] ; do
        read -p "Please type 'yes' to proceed or 'quit' for exit: " confirmation
        case $confirmation in
            'yes')
                echo ''
                echo "Continuing ..."
                break
            ;;
            'quit')
                echo ''
                echo "Exiting..."
                exit
            ;;
            *)
                confirmation=''
                echo ''
                echo "Wrong data entered, please try again."
                echo ''
            ;;
        esac
    done
fi

#echo "Deleting user '$rabbitmq_user' ..."
echo ''
rabbitmqctl delete_user $rabbitmq_user
sleep 2

#echo "Deleting vHost '$rabbitmq_vhost' ..."
echo ''
rabbitmqctl delete_vhost $rabbitmq_vhost
sleep 2

#echo "Creating user '$rabbitmq_user' ..."
echo ''
rabbitmqctl add_user $rabbitmq_user $rabbitmq_password
sleep 2

#echo "Updating user tags ..."
echo ''
rabbitmqctl set_user_tags $rabbitmq_user administrator
sleep 2

#echo "Creating vHost '$rabbitmq_vhost' ..."
echo ''
rabbitmqctl add_vhost $rabbitmq_vhost
sleep 2

#echo "Assigning permissions ..."
echo ''
rabbitmqctl set_permissions -p $rabbitmq_vhost $rabbitmq_user ".*" ".*" ".*"
sleep 2

echo ''
echo "RabbitMQ Configuration Completed."

