#!/bin/bash

wget_files_list=${1:-./wget-files.list}
wget_log=/tmp/wget.log

BUILD_ROOT=/opt/image-builder

rm ./status.log
rm "$wget_log"


status() {
    echo "$2    $1" >> ./status.log
}

mdg() {
    cat << EOF

$@
EOF
}

line_number=0
while IFS=$'\t' read -r name path url
do
    line_number=$(($line_number + 1))

    if [[ "$name" =~ ^# ]] ; then
        continue
    fi

    if [[ -z "$name" ]] ; then
        msg "Skipping empty line $line_number"
        continue
    fi

    eval "path=${path}"
    if [[ -z "$path" ]] ; then
        msd "Skipping line $line_number: Path is empty!"
        continue
    fi

    if [[ -z "$url" ]] ; then
        msg "Skipping line $line_number: URL is empty!"
        continue
    fi

    mkdir -p $path

    if [[ -f "$path/$name" ]] ; then
        status "$path/$name" "SKIPPED"
    else
        msg "Downloading '$url'"
        if [[ "$name" = '.' ]] ; then
            wget -N -P "$path" $url
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
done < $wget_files_list


if grep -q 'FAILED' ./status.log ; then
    msg "There are errors while downloading:"
    grep 'FAILED' ./status.log
fi

