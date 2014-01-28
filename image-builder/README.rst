Image builder
=============

Use the 'make' utility to start build new Windows image.

During build preparation this folder will be copied entirely to the **/opt/image-builder** folder. In this document we refer to that folder using variable **IMAGE_BUILDER_ROOT**.

Prerequisites
-------------
The following ISO files **MUST** be placed under **$IMAGE_BUILDER_ROOT/libvirt/images** folder:
* ws-2012-eval.iso - Windows installation ISO file. Must be renamed or simlinked.
* virtio-win-0.1-52.iso - VirtIO drivers for Windows.

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

