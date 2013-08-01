#!/bin/bash
#
#    Copyright (c) 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#    Author: Igor Yozhikov <iyozhikov@mirantis.com>
#
#    Make/Set proper Openstack credentials file and change OS_CREDS_FILE variable.
#
URL_PREFIX="http://172.18.124.100:8888/"
# source openstack credentials file
OS_CREDS_FILE="/home/stack/devstack/openrc"
if [ ! -f "$OS_CREDS_FILE" ];then
 	echo -e "Set proper openstack credentials file path, file \"$OS_CREDS_FILE\" - not found, exiting!"
	exit 1
fi
source $OS_CREDS_FILE admin admin


function get_remote_list()		
{
	_EXCEPT_FILTER=".json"	
	_LIST=$(curl $URL_PREFIX 2>&1 | grep -o -E 'href="([^"#]+)"' | cut -d'"' -f2 | grep -ivE '^http|^/|'$_EXCEPT_FILTER)
	if [ $? -eq 0 ]; then
		echo $_LIST
	fi
}

function print_remote_imagelist()
{
	_ln=0
	_IMGS_LIST=""
	_REMOTE_LIST=$(get_remote_list)
	if [ -n "$_REMOTE_LIST" ]; then
        	for item in $_REMOTE_LIST
	        do  	
        	        let _ln+=1
                	if [ -z "$_IMGS_LIST" ]; then
                        	_IMGS_LIST="$_ln\t$item"
	                else
        	                _IMGS_LIST="$_IMGS_LIST\n$_ln\t$item"
                	fi  
	        done
	        echo $_IMGS_LIST
	else
	        exit 1
	fi
}

function get_remote_json()
{
	_IMG=$1
	_JSON=${_IMG%%.*}
	_RESULT=$(curl $URL_PREFIX$_JSON.json)		
	_IS_VALID=$(echo "$_RESULT" | sed -ne '/^{/,/}$/ =')
	if [ -n "$_IS_VALID" ]; then 
	        echo "$_RESULT" 
        fi
} 

function punch_glance()
{
	_img=$1
	shift
	_json_data=$@
	_image_name=${_img%%.*}
	echo -e "Deleteing image \"$_image_name\"..." 
	glance image-delete $_image_name
	echo -e "Loading image \"$_image_name\"..."
	glance image-create --name $_image_name --disk-format qcow2 --container-format bare --copy-from $URL_PREFIX$_img --is-public true --property murano_image_info="$_json_data"
	if [ $? -ne 0 ];then
                echo -e "Error during importing \"$_image_name\" into glance, exiting!"
                exit 1
        else
                echo -e ".....Image loading in PROGRESS, watch it through: \"glance image-list | grep $_image_name\"!.....\n\n"
        fi  
}

function prepare_remote()
{
	_img=$1
	_remote_json_data=$(get_remote_json $_img)
	if [ -z "$_remote_json_data" ]; then
		echo -e "WARNING! Can't get image JSON description file from remote or it's empty!"
		read -p "Continue Y/N?" input
		case $input in
			N | n)
				exit 2
				;;
			* ) 
				
				;;
		esac
	fi
	punch_glance "$_img" "$_remote_json_data"
}

# Workflow
while true
do
	IMGS_LIST=$(print_remote_imagelist)
	if [ $? -eq 0 ]; then
		echo -e "Choose image number or q for exit and press [ENTER]:"
		echo -e "$IMGS_LIST\n"
		_items=$(echo -e $IMGS_LIST | wc -l)
		read userInput		
		shopt -s extglob
		_digits="+([1-$_items])"
		case $userInput in			
			$_digits)
				_choosen_item=$(echo -e $IMGS_LIST | sed -ne "$userInput"p | awk '{print $2}')
				echo -e "CHOICE : $_choosen_item"
				prepare_remote $_choosen_item
				;; 
			q | Q )
				echo -e "...exiting"
				break
				;;	
			
			*)
				echo "Invalid choice \"$userInput\", reloading..."
				;;
		esac
	else
		echo "Check \"URL_PREFIX\" variable, exiting!"
		break
		exit 1
	fi
done
#get_remote_json ws-2012-core.qcow2
