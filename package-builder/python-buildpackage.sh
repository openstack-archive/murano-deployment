#!/bin/bash

set -o xtrace
set -o nounset

source ./functions.sh



curr_dir=$(pwd)
pkg_upstream_dir=$1

[ -z "$pkg_upstream_dir" ] && die "Upstream directory must be provided."

pkg_build_dir=${BUILD_DIR:-$(cd $pkg_upstream_dir/.. && pwd)}

mkdir -p $pkg_build_dir


# Variables required for templates and build process
#---------------------------------------------------
cd $pkg_upstream_dir

pkg_upstream_url=$(git remote -v | awk '/fetch/{print $2}')

# Run setup.py once to resolve and install dependencies
# This workaround prevents us from getting gurbage in variables below
python setup.py --version

pkg_name=$(python setup.py --name)
pkg_ver_long=$(python setup.py --version)
pkg_ver=${pkg_ver_long}
#pkg_ver=${pkg_ver%.*}
#pkg_ver=${pkg_ver%.*}

pkg_fullname_long=${pkg_name}-${pkg_ver_long}
pkg_fullname=${pkg_name}-${pkg_ver}

pkg_descr_short=$(python setup.py --description)
pkg_descr_long=$(python setup.py --long-description)

pkg_homepage=$(python setup.py --url)

pkg_author=$(python setup.py --author)

pkg_license=$(python setup.py --license)

pkg_maint_name=$(python setup.py --maintainer)
pkg_maint_email=$(python setup.py --maintainer-email)

pkg_last_commit=$(git log | grep -m1 ^commit)
#---------------------------------------------------


# Importing and setting up default values for vars
#-------------------------------------------------
if [ -f $curr_dir/$pkg_name/debian/vars ] ; then
    source $curr_dir/$pkg_name/debian/vars
fi

DEB_BUILD_DEPENDS=${DEB_BUILD_DEPENDS:-'debhelper (>= 8.0.0)'}

export DEBFULLNAME=${DEBFULLNAME:-$pkg_maint_name}
export DEBEMAIL=${DEBEMAIL:-$pkg_maint_email}
#-------------------------------------------------


# Copy tarball to the build_dir
#------------------------------
python setup.py sdist

cp dist/${pkg_fullname}.tar.gz $pkg_build_dir/${pkg_name}_${pkg_ver}.orig.tar.gz
#------------------------------



# Extract orig.tar.gz archive
#----------------------------
cd $pkg_build_dir

rm -rf ${pkg_fullname}

tar -xzvf ${pkg_name}_${pkg_ver}.orig.tar.gz
#----------------------------



# Create files required for debianization
#----------------------------------------
cd $pkg_build_dir/$pkg_fullname

mkdir -p debian/source


echo '8' > debian/compat


echo '3.0 (quilt)' > debian/source/format


cat << EOF > debian/control
Source: ${pkg_name}
Section: unknown
Priority: extra
Maintainer: ${DEBFULLNAME} <${DEBEMAIL}>
Build-Depends: ${DEB_BUILD_DEPENDS}
Standards-Version: 3.9.2
Homepage: ${pkg_homepage}
Vcs-Git: ${pkg_upstream_url}

Package: ${pkg_name}
Architecture: all
Depends: \${misc:Depends}, \${python:Depends} $([ -n "$DEB_DEPENDS" ] && echo ", $DEB_DEPENDS")
Description: ${pkg_descr_short}
$(echo "${pkg_descr_long}" | awk '/^$/{print " .";next}//{print " " $0}')
EOF


cat << EOF > debian/changelog
${pkg_name} (${pkg_ver}-1) unstable; urgency=low

  * Initial build, based on ${pkg_last_commit}

 -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -R)
EOF


cat << EOF > debian/copyright
This package was debianized by ${DEBFULLNAME} on $(date -R)

It was downloaded from ${pkg_upstream_url}

Upstream author: ${pkg_author}

License: ${pkg_license}
EOF



cat << EOF > debian/rules
#!/usr/bin/make -f
%:
	dh \$@ --buildsystem python_distutils --with python2

override_dh_clean:
	rm -rf \$(CURDIR)\\build
	dh_clean
EOF
chmod +x debian/rules
#----------------------------------------



# Update debian files from this repo
#-----------------------------------
if [ -d "$curr_dir/$pkg_name" ] ; then
	cp -r "$curr_dir/$pkg_name/debian" .
fi
#-----------------------------------



# Build package
#--------------
dpkg-buildpackage -us -uc
#--------------
