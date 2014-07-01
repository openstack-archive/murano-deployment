Image builder
=============

Use the 'make' utility to start build new Windows image.

During build preparation this folder will be copied entirely to the **/opt/image-builder** folder. In this document we refer to that folder using variable **IMAGE_BUILDER_ROOT**.

config.ini
----------

Config file consists of the following sections:
* Default section - Could be names as DEFAULT only. Only one section should be defined, and it should be the first section in the file. This section defines variables which are evaluated and exported as reqular env variables during scripts execution. These variables could be used in subsequent sections (as IMAGE_BUILDER_ROOT does).
* Prerequisite sections - Could be named as you want. Any number of sections is allowed. These sections define options which allows to perform various tasks on dependencies, such as validating, renaming, downloading.

Dependency options
""""""""""""""""""

* name - file name for the dependency
* url - URL which could be used to download missing dependency file
* path - path where the file will be stored
* mandatory - identifies the dependency as "must exists or die", allowed values are 'true' and 'false'
* skip - skips section, helps when you need to skip a section and do not want to comment many lines :) Allowed values are 'true' and 'false'

Prerequisites
-------------
Files that **MUST** be placed under **$IMAGE_BUILDER_ROOT/libvirt/images** folder are defined in config file with "mandatory = 'true'" option.

Files that **MUST** be placed under **$IMAGE_BUILDER_ROOT/share/files** are described in README file under **share/files** subfolder.

Required steps
--------------

1. Run **install.sh** to install required prerequisites and configure system. This script will create folder structure, install required packages and configure Samba share required by build script.
2. Run **make build-root** to update build root directory content.
3. Copy prerequisite files to their folders.
4. Run **make test-build-files** to ensure that all files are in place.
5. Run **make** to show available image targets.
6. Run **make <image target>** to build image.
7. Image file should be saved under **$IMAGE_BUILDER_ROOT/libvirt/images** folder.

* Run **make clean** to remove files produced by this makefile only. NOTE: 'static files' (prerequisites) will be kept.
* Run **make clean-all** to run clean other files, that were prodiced by other makefiles.

