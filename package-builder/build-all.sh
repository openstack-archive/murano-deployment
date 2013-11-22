#!/bin/bash

set -o xtrace

curr_dir=$(pwd)
pkg_build_dir=~/build_dir

source ./functions.sh


upstream_repo_list='
https://github.com/stackforge/murano-api.git
'

#https://github.com/stackforge/murano-dashboard.git
#https://github.com/stackforge/murano-repository.git
#'

rm -rf $pkg_build_dir/debuild

mkdir $pkg_build_dir/debuild
mkdir $pkg_build_dir/upstream

for url in $upstream_repo_list ; do
    repo_name=${url##*/}
    repo_name=${repo_name%.git}

    git_clone $url $pkg_build_dir/upstream/$repo_name 'master'

    cd $curr_dir

    BUILD_DIR=$pkg_build_dir/debuild ./python-buildpackage.sh $pkg_build_dir/upstream/$repo_name
done

