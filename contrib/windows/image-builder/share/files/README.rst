Prerequisite files
==================

This folder contains files, required to build Windows image.

Subfolders hold files that are depend on Windows version.

Cloned from Git repo this folder will contain only the following files:
* userdata.py

The following files **MUST** be added to the folder **$BUILD_ROOT/image-builder/share/files** by hands.
* CloudbaseInitSetup_Beta.msi
* Far30b3367.x64.20130426.msi
* SysinternalsSuite.zip
* Git-1.8.1.2-preview20130201.exe
* unzip.exe

The following files will be build by other makefiles:
* CoreFunctions.zip

The following files should be also added to the folder **$BUILD_ROOT/image-builder/share/files**, but in future they might also be built automatically:
* MuranoAgent.zip

