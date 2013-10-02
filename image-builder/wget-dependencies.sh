#!/bin/bash

dependency_list=${1:-./dependency.list}
BUILD_ROOT=/opt/image-builder
wget_log=/tmp/wget.log


rm ./status.log
rm "$wget_log"


status() {
    echo "$2    $1" >> ./status.log
}


line_number=0
while IFS=$'\t' read -r name path url
do
    line_number=$(($line_number + 1))

    if [[ "$name" =~ ^# ]] ; then
        continue
    fi

    if [[ -z "$name" ]] ; then
        echo "Skipping line $line_number: File name is empty!"
        continue
    fi

    eval "path=${path}"
    if [[ -z "$path" ]] ; then
        echo "Skipping line $line_number: Path is empty!"
        continue
    fi

    if [[ -z "$url" ]] ; then
        echo "Skipping line $line_number: URL is empty!"
        continue
    fi

    mkdir -p $path

    if [[ -f "$path/$name" ]] ; then
        status "$path/$name" "SKIPPED"
    else
        if [[ "$name" = '.' ]] ; then
            wget -P "$path" $url
            wget_result=$?
        else
            wget -P "$path" -O "$name" $url
            wget_result=$?
        fi
        if [[ $wget_result -eq 0 ]] ; then
            status "$url" "OK"
        else
            status "$url" "FAILED"
        fi
    fi
done < $dependency_list


if grep -q 'FAILED' ./status.log ; then
    cat << EOF

There are errors while downloading:
EOF
    grep 'FAILED' ./status.log
fi

