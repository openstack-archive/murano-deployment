
.PHONY: force clean usage


image_name :=
build_root := /opt/image-builder
shared_files_dir := ${build_root}/share/files
shared_scripts_dir := ${build_root}/share/scripts
shared_images_dir := ${build_root}/share/images
libvirt_images_dir := ${build_root}/libvirt/images
ps_modules_dir := ${CURDIR}/../WindowsPowerShell

image_list := ws-2008r2-core ws-2012-core

dirs := ${build_root}
dirs += ${libvirt_images_dir}
dirs += ${shared_files_dir}
dirs += ${shared_scripts_dir}
dirs += ${shared_images_dir}


# Static files == files that are not changed from one build to another
# Typically it's binary prerequisite files
static_files := ${libvirt_images_dir}/ws-2012-eval.iso
static_files += ${libvirt_images_dir}/virtio-win-0.1-52.iso
static_files += ${shared_files_dir}/CloudbaseInitSetup_Beta.msi
static_files += ${shared_files_dir}/Far30b3367.x64.20130426.msi
static_files += ${shared_files_dir}/Git-1.8.1.2-preview20130201.exe
static_files += ${shared_files_dir}/SysinternalsSuite.zip
static_files += ${shared_files_dir}/unzip.exe
static_files += ${shared_files_dir}/userdata.py
# TODO: move the following files to the 'dynamic files' as they are 'version dependent'
static_files += ${shared_files_dir}/MuranoAgent.zip


# Dynamic files == files that might be updated from repository during the build.
dynamic_files := ${shared_files_dir}/CoreFunctions.zip


build_files := ${shared_files_dir}/ws-2012-core/autounattend.xml
build_files += ${shared_files_dir}/ws-2012-core/unattend.xml
build_files += ${build_root}/install-vm.sh
build_files += ${shared_scripts_dir}/wpi.ps1
#build_files += ${shared_scripts_dir}/Start-Sysprep.ps1


usage : 
	@echo ''
	@echo 'Available build targets:'
	@echo '* clean - clean files related to image build process.'
	@echo '* clean-all - clean all files (including produces by other makefiles).'
	@echo '* build-root - create directory structure.'
	@echo '* test-build-files - test if all prerequisites are in place.'
	@echo ''
	@echo 'Available image targets:'
	@for name in ${image_list} ; do \
		echo "* $$name"; \
	done
	@echo ''


clean :
	-rm -f ${libvirt_images_dir}/*.flp
	-rm -f ${libvirt_images_dir}/*.qcow2
	-rm -f ${libvirt_images_dir}/*.img


clean-all : clean
	${MAKE} -C ${ps_modules_dir} clean


build-root : ${dirs}
	cp -r * ${build_root}


${dirs} :
	mkdir -p $@


test-build-files : ${build_files} ${static_files} ${dynamic_files}


# Rule to check if all 'static files' are in place
${static_files} :
	@[ -f $@ ] || echo "STOP: File not found '$@'"; exit 1


# Rule to copy updated 'build files'
${build_files} : ${build_root}/% : ${CURDIR}/%
	cp $< $@


# Rules for 'dynamic files'
#----------
${shared_files_dir}/CoreFunctions.zip : ${ps_modules_dir}/CoreFunctions.zip


${ps_modules_dir}/CoreFunctions.zip :
	${MAKE} -C ${ps_modules_dir} all
	cp $@ ${shared_files_dir}/$(F@)
#----------


ifndef image_name

${image_list} :
	@echo "Image name: '$@'"
	@echo "Starting make recurcievely ..."
	${MAKE} -e image_name=$@ $@

else

${image_name} : ${shared_images_dir}/${image_name}.qcow2


${shared_images_dir}/${image_name}.qcow2 : test-build-files ${libvirt_images_dir}/${image_name}.flp
	env BUILD_ROOT=${build_root} VM_NAME=${image_name} FLOPPY_IMG=${image_name}.flp ${build_root}/install-vm.sh


${libvirt_images_dir}/${image_name}.flp : ${shared_files_dir}/${image_name}/autounattend.xml
	dd bs=512 count=2880 if=/dev/zero of=${libvirt_images_dir}/${image_name}.flp
	mkfs.msdos ${libvirt_images_dir}/${image_name}.flp
	-mkdir -p /media/floppy/
	mount -o loop ${libvirt_images_dir}/${image_name}.flp /media/floppy/
	cp ${shared_files_dir}/${image_name}/autounattend.xml /media/floppy/autounattend.xml
	umount /media/floppy


${shared_files_dir}/${image_name}/autounattend.xml : ;

endif

