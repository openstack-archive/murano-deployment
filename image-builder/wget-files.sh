#!/bin/bash

mode=${1:-'print'}
config_file=${2:-'./config.file'}

BUILD_ROOT=/opt/image-builder

trim() {
    echo "$1"
}

msg() {
    cat << EOF

* $@
EOF
}

err() {
    cat << EOF >&1

* $@
EOF
}

status() {
    echo "$2 $1" >> ./status.log
}

process_item() {
    case $mode in
        'download')
            download_item
        ;;
        'test')
            test_item
        ;;
        'print')
            print_item
        ;;
    esac
}

print_item() {
    validate_item_property
    if [ $item_invalid = 'true' ] ; then
        msg "Bad input in section '$section'"
    fi

    cat << EOF

Section   = $section
Name      = $item_name
Path      = $item_path
URL       = $item_url
Skip      = $item_skip
Mandatory = $item_mandatory
EOF
}

validate_item_property() {
#    if [[ -z "$item_name" ]] ; then
#        err "Section '$section', line $line_number: Name is empty!"
#        item_invalid='true'
#    fi

    if [[ -z "$item_path" ]] ; then
        err "Section '$section', line $line_number: Path is empty!"
        item_invalid='true'
    fi

    if [[ -z "$item_url" ]] ; then
        err "Section '$section', line $line_number: URL is empty!"
        item_invalid='true'
    fi
}

download_item() {
    local file_name

    validate_item_property
    if [ $item_invalid = 'true' ] ; then
        msg "Bad input in section '$section'"
    fi

    if [ "$item_skip" = 'true' ] ; then
        msg "Skipping section '$section'"
        return
    fi

    mkdir -p $item_path

    if [[ -z "$item_name" ]] ; then
        file_name=$(basename $item_url)
    else
        file_name=$item_name
    fi

    if [[ -f "$item_path/$file_name" ]] ; then
        if [[ "$item_force_update" = 'true' ]] ; then
            rm -f "$item_path/$file_name"
        else
            msg "Item '$item_path/$file_name' exists, skipping"
            status "$item_path/$file_name" "SKIPPED"
            return
        fi
    fi

    msg "Downloading from '$item_url'"
    if [[ -z "$item_name" ]] ; then
        wget --content-disposition --directory-prefix="$item_path" --timestamping $item_url
        wget_result=$?
    else
        wget --content-disposition --output-document="$item_path/$file_name" $item_url
        wget_result=$?
    fi

    if [[ $wget_result -eq 0 ]] ; then
        status "$item_url" "OK"
    else
        status "$item_url" "FAILED"
    fi
}


test_item() {
:
}

#-------------------------------------------------------------------------------

line_number=0
section=''
while IFS='=' read -r key value
do
    line_number=$(($line_number + 1))

    [ -z "$key" ] && continue

    [[ "$key" =~ ^# ]] && continue

    if [[ "$key" =~ \[.*\] ]] ; then
        key=${key#*[}
        key=${key%]*}
        if [ -n "$section" ] ; then
            process_item
        fi
        section=$key
        item_name=''
        item_path=''
        item_url=''
        item_mandatory='false'
        item_skip='false'
        item_invalid='false'
        item_force_update='false'
        item_image_type=''
    fi

    key=$(trim $key)
    value=$(trim $value)

    case $key in
        'name')
            item_name=$value
        ;;
        'path')
            eval "item_path=${value}"
        ;;
        'url')
            item_url=$value
        ;;
        'skip')
            item_skip=$value
        ;;
        'mandatory')
            item_mandatory=$value
        ;;
        'force_update')
            item_force_update=$value
        ;;
        'image_type')
            eval "item_image_type=${value}"
        ;;
    esac
done < $config_file
process_item


if grep -q 'FAILED' ./status.log ; then
    cat << EOF

One or more errors occured while downloading the files
******************************************************

$(grep 'FAILED' ./status.log)

******************************************************
EOF
exit 1
fi
