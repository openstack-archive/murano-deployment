#!/bin/sh -x
#

cd ~/tests

#clone and clean github pages
rm -rf murano-docs
git clone git@github.com:murano-docs/murano-docs.github.io.git murano-docs
cd murano-docs
ls -A1 | grep -v -e '\.git' | xargs git rm -rf
cd ~/tests

#clone Murano Docs
rm -rf murano-docs
git clone https://github.com/stackforge/murano-docs

#copy site
cp murano-docs/site/index.html ~/tests/murano-docs/

#generate murano-manual
cd murano-docs/src/murano-manual
mvn clean generate-sources

#copy murano-manual
mkdir -p ~/tests/murano-docs/docs/murano-manual
cp -r target/docbkx/webhelp/murano-manual/* ~/tests/murano-docs/docs/murano-manual
cp target/docbkx/pdf/murano-manual.pdf ~/tests/murano-docs/docs/murano-manual
cd ~/tests

#generate murano-deployment-guide
cd murano-docs/src/murano-deployment-guide
mvn clean generate-sources

#copy murano-deployment-guide
mkdir -p ~/tests/murano-docs/docs/murano-deployment-guide
cp -r target/docbkx/webhelp/murano-deployment-guide/* ~/tests/murano-docs/docs/murano-deployment-guide
cp -r target/docbkx/pdf/murano-deployment-guide.pdf ~/tests/murano-docs/docs/murano-deployment-guide
cd ~/tests

#commit generated data
cd ~/tests/murano-docs
git config user.email "murano-eng@mirantis.com"
git config user.name "murano-docs"
git add .
git commit -am "generated `date`."
git push origin master
