#!/bin/sh

get_boundary() {
	local udf=${1}

	sed -nr 's/Content-Type: multipart\/mixed; boundary="(.*)"/\1/p' "${udf}"
}

split_multipart() {
	local udf=${1}
	local n=0
	
	shift
	while [ $# -ge 2 ] ; do
		tail -n +$((${1} + 1)) "${udf}" | head -n $((${2} - ${1} - 1)) | \
		  awk "//{if(f2==1){print \$0;next}} /^$/{if(f2==0){f1=1;next}} //{if(f1==1){f2=1;print \$0}}" > "${udf}.part.${n}"
		echo ${n}
		n=$((${n} + 1))
		shift
	done
}

exec_userdata() {
	local udf=${1}
	local boundary=$(get_boundary "${udf}")
	local boundary_line_numbers=""
	local n=""
	local parts=""

	if [ -z "${boundary}" ] ; then
		exec_script "${udf}"
	else
		boundary_line_numbers=$(awk -F ':' "/\-\-${boundary}/{s=s \" \" NR} END{print s}" "${udf}")
		parts=$(split_multipart "${udf}" $boundary_line_numbers)

		for n in ${parts} ; do
			exec_script "${udf}.part.${n}"
		done
	fi
}

exec_script() {
	local udf=${1}
	local shebang="#!/bin/sh"
	local a=""

	read a < "${udf}"
	[ "${a#${shebang}}" = "${a}" ] &&
		{ msg "user data not a script"; return 0; }

	chmod 755 "${udf}"
	exec "${udf}"
}

