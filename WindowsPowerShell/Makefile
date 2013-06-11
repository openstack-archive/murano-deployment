
.PHONY : all
.PHONY : force
.PHONY : usage
.PHONY : module-list


module_dir := Modules
module_list := $(shell find Modules -maxdepth 1 -type d -printf "%P ")
module_name :=


usage :
	@echo "Available targets:"
	@echo "* all - make all modules"
	@echo "* module-list - lists all modules under '${module_dir}'"
	@echo "* <module name> - build module named <module name>"


module-list :
	@echo "Available modules:"
	@for name in ${module_list} ; do \
		echo "* $$name"; \
	done
	@echo ""


ifndef module_name

all : ${module_list}


${module_list} :
	@echo ''
	@echo 'Calling make recurcievely ...'
	$(MAKE) -e module_name=$@ $@

else

${module_name} : ${module_name}.zip


${module_name}.zip : ${module_dir}/${module_name}.content
	@echo ''
	@echo "Zipping module '${module_name}' ..."
	-rm -f $@
	cd ${module_dir} && zip -r $@ ${module_name}
	mv ${module_dir}/$@ ${CURDIR}


${module_dir}/${module_name}.content : force
	@echo ""
	@echo "Generating file list for module '${module_name}' ..."
	cd ${module_dir} && find ${module_name} > $(@F).tmp
	[ -f $@ ] || cp $@.tmp $@
	cmp -s $@ $@.tmp || cp $@.tmp $@
	rm $@.tmp

endif


clean :
	@echo ''
	@echo 'Cleaning temporary files ...'
	rm -f ${module_dir}/*.content
	rm -f ${module_dir}/*.content.tmp
	rm -f *.zip


