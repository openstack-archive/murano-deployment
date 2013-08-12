#!/bin/sh -x
#

cd ~/tests

#clone and clean github pages
rm -rf gh-pages
git clone -b gh-pages git@github.com:Mirantis/murano-docs.git gh-pages
cd gh-pages
git rm -rf '!(.git|.nojekyll|CNAME)'
cd ~/tests

#clone Murano Docs
rm -rf murano-docs
git clone https://github.com/stackforge/murano-docs

#copy site
cp murano-docs/site/index.html ~/tests/gh-pages/

#generate murano-manual
cd murano-docs/src/murano-manual
mvn clean generate-sources

#copy murano-manual
mkdir -p ~/tests/gh-pages/docs/murano-manual
cp -r target/docbkx/webhelp/murano-manual/* ~/tests/gh-pages/docs/murano-manual
cp target/docbkx/pdf/murano-manual.pdf ~/tests/gh-pages/docs/murano-manual
cd ~/tests

#generate murano-deployment-guide
cd murano-docs/src/murano-deployment-guide
mvn clean generate-sources

#copy murano-deployment-guide
mkdir -p ~/tests/gh-pages/docs/murano-deployment-guide
cp -r target/docbkx/webhelp/murano-deployment-guide/* ~/tests/gh-pages/docs/murano-deployment-guide
cp -r target/docbkx/pdf/murano-deployment-guide.pdf ~/tests/gh-pages/docs/murano-deployment-guide
cd ~/tests

#commit generated data
cd ~/tests/gh-pages
git config user.email "tnurlygayanov@mirantis.com"
git config user.name "Timur Nurlygayanov"
git add .
git commit -am "generated `date`."
git push origin gh-pages
