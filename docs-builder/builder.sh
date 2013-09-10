#!/bin/sh -x
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

#create temp directory where we going to work
TEMP=$PWD/temp-$(date +%s)
mkdir "${TEMP}"

#clone and clean github pages
cd "${TEMP}"
git clone git@github.com:murano-docs/murano-docs.github.io.git murano-docs
cd murano-docs
ls -A1 | grep -v -e '\.git' | xargs git rm -rf

for version in "0.1" "0.2" "latest"
do
    cd "${TEMP}"

    if [ ${version} = "latest" ]; then
        guides="murano-manual murano-deployment-guide"
        branch="master"
    elif [ ${version} = "0.2" ]; then
        guides="developers-guide administrators-guide user-guide"
        branch="release-${version}"
    elif [ ${version} = "0.1" ]; then
        guides="murano-manual murano-deployment-guide"
        branch="release-${version}"
    else
        guides="developers-guide murano-deployment-guide"
        branch="release-${version}"
    fi

    git clone -b ${branch} git@github.com:stackforge/murano-docs.git docs-${version}
    cd docs-${version} && git pull && cd ..

    for guide in ${guides}
    do
        cd "${TEMP}/docs-${version}/src/${guide}"
        mvn clean generate-sources

        built_manual=${TEMP}/murano-docs/${version}/${guide}
        mkdir -p "${built_manual}"
        cp -r "target/docbkx/webhelp/${guide}"/* "${built_manual}"
        cp "target/docbkx/pdf/${guide}.pdf" "${built_manual}"
    done
done

#commit generated data
cd "${TEMP}/murano-docs"
git config user.email "murano-eng@mirantis.com"
git config user.name "murano-docs"
git add .
git commit -am "generated `date`."
git push origin master

#clean-up
rm -rf "${TEMP}"