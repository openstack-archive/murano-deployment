#!/bin/sh -x

VERSIONS[0]="0.1"
VERSIONS[1]="0.2"

#create temp directory where we going to work
TEMP=$PWD/temp-$(date +%s)
mkdir ${TEMP}

#clone and clean github pages
cd ${TEMP}
git clone git@github.com:murano-docs/murano-docs.github.io.git murano-docs
cd murano-docs
ls -A1 | grep -v -e '\.git' | xargs git rm -rf

for version in ${VERSIONS[@]}
do
    cd ${TEMP}
    git clone -b release-${version} git@github.com:stackforge/murano-docs.git docs-${version}

    for manual in "murano-manual" "murano-deployment-guide"
    do
        cd ${TEMP}/docs-${version}/src/${manual}
        mvn clean generate-sources

        built_manual=${TEMP}/murano-docs/docs/v${version}/${manual}
        mkdir -p ${built_manual}
        cp -r target/docbkx/webhelp/${manual}/* ${built_manual}
        cp target/docbkx/pdf/${manual}.pdf ${built_manual}
    done
done

#commit generated data
cd ${TEMP}/murano-docs
git config user.email "murano-eng@mirantis.com"
git config user.name "murano-docs"
git add .
git commit -am "generated `date`."
git push origin master
