# Package Builder

This folder contains a set of scripts and files used to automate packaging the Murano-* components.

The main workflow is quite simple now:

1. Clone/Update murano-deployment repo
2. Change directory to 'package-builder'
3. Run *build-all.sh*
4. When building completed - open folder *\~/build_dir/debuild*
5. Copy content of murano-*.debian.tar.gz to appropriate repos in OBS

What the scripts actually do:

1. Create temporary build folder *~/build_dir*.
2. Clone multiple *murano-\** repositories to *\~/build_dir/upstream*.
3. Extract basic package-related information for each component.
4. Create original tarball orig.tar.gz files for each component.
5. Create initial build bir based on component's *.orig.tar.gz* file.
5. Create initial set of files for Debian package for each component.
6. Check if there is a folder for each component in *package-builder* folder. If exists - copy (with overwriting) files to each component's build dir.
7. Build package for each component.

Main idea behind this scripts is to automate passing package-related information from upstream repository and customize each package as needed before build.

All the required changes to components should be made in files which overwrites initial debian configuration files - these changes should be made in files located in appropriate subdirectory. For example, for *murano-api* changes should be made in files located in *./murano-api/debian/*
