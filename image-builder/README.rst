Image builder
=============

Use the 'make' utility to start build new Windows image.

During build preparation this folder will be copied entirely to the **/opt/image-builder** folder. We refer to that folder using variable **BUILD_ROOT**.

Prerequisites
-------------
The following ISO files **MUST** be placed under **$BUILD_ROOT/libvirt/images** folder:
* ws-2012-eval.iso - Windows installation ISO file. Must be renamed or simlinked.
* virtio-win-0.1-52.iso - VirtIO drivers for Windows.

Files that **MUST** be placed under **$BUILD_ROOT/share/files** are described in README file under **share/files** subfolder.

Required steps
--------------

1. Run **make build-root** to create directory structure. It will be built under '/opt/image-builder' folder, which is internally referred by **BUILD_ROOT** variable.
2. Copy prerequisite files to their folders.
3. Run **make test-build-files** to ensure that all files are in place.
4. Run **make** to show available image targets.
5. Run **make <image target>** to build image.
6. Image file should be saved under **$BUILD_ROOT/libvirt/images** folder.

* Run **make clean** to remove files produced by this makefile only. NOTE: 'static files' (prerequisites) will be kept.
* Run **make clean-all** to run clean other files, that were prodiced by other makefiles.

