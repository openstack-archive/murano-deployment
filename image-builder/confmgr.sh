#!/bin/bash

config_file=${CONFIG_FILE:-'./config.ini'}
status_file=$(tempfile)

#-------------------------------------------------------------------------------

trim() {
    echo "$@"
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
    echo -e "$@" >> $status_file
}


get_item() {
    validate_item
    if [ $item_invalid = 'true' ] ; then
        return
    fi


}


print_item() {
    validate_item
    if [ $item_invalid = 'true' ] ; then
        return
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


validate_item() {
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

    if [ $item_invalid = 'true' ] ; then
        msg "Bad input in section '$section'"
    fi
}


download_item() {
    local file_name

    validate_item
    if [ $item_invalid = 'true' ] ; then
        return
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
            status "SKIPPED\t$item_path/$file_name"
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
        status "OK\t$item_url"
    else
        status "FAILED\t$item_url"
    fi
}


test_item() {
    local file_name

    validate_item
    if [ $item_invalid = 'true' ] ; then
        return
    fi

    if [[ -z "$item_name" ]] ; then
        file_name=$(basename $item_url)
    else
        file_name=$item_name
    fi

    if [[ ! -f "$item_path/$file_name" ]] ; then
        if [[ "$item_mandatory" = 'true' ]] ; then
            status "NOT_FOUND\t$item_path/$file_name"
        else
            status "WARNING\t$item_path/$file_name"
        fi
    fi

}


process_section() {
    case $action in
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


process_config() {

    args=("$@")
    action="$1"

    rm -f $status_file

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
                process_section
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

            continue
        fi

        key=$(trim $key)
        value=$(trim $value)

        echo "'$action' '$section' '$key' '$value'"
        case $action in
            'get')
                if [[ "$section" = "${args[1]}" && "$key" = "${args[2]}" ]]; then
                    eval "echo ${value}"
                fi
            ;;
        esac

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
    process_section


    if [[ "$action" = 'download' ]] ; then
        if grep -q 'FAILED' $status_file ; then
            cat << EOF

ERROR:
- One or more errors occured while downloading the files
********************************************************

$(grep 'FAILED' $status_file)

********************************************************
EOF
            exit 1
        fi

        exit 0
    fi


    if [[ $action = 'test' ]] ; then
        if grep -q 'WARNING' $status_file ; then
            cat << EOF

WARNING:
- One or more non-mandatory files not found
*******************************************

$(grep 'WARNING' $status_file)

*******************************************
EOF
        fi

        if grep -q 'NOT_FOUND' $status_file ; then
            cat << EOF

ERROR:
- One or more mandatory files not found
***************************************

$(grep 'NOT_FOUND' $status_file)

***************************************
EOF
            exit 1
        fi

        exit 0
    fi
}

#-------------------------------------------------------------------------------


# If there are parameter from command line then call function immediately
# This check allows this file to be included in others
if [[ -n "$1" ]]; then
    process_config "$@"
fi
