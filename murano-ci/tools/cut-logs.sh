#set -o xtrace

from_date=${1} # $(date +'%Y-%m-%d' -d 'yesterday')
from_time=${2} # '00:00:00'
to_date=${3}   # $(date +'%Y-%m-%d')
to_time=${4}   # '00:00:00'

shift 4
os_components=$@

BUILD_TAG=${BUILD_TAG:-noname}
LOG_DIR=${LOG_DIR:-/var/log}
OUTPUT_DIR=${OUTPUT_DIR:-.}

program="BEGIN {
  from_ts = \"${from_date}T${from_time}\";
  to_ts = \"${to_date}T${to_time}\";
}
{
  ts = \$1 \"T\" \$2;
  if (ts >= from_ts && ts < to_ts) print \$0;
}"

function split_logs() {
    local component_name=$1
    local input_file
    local output_file

    shift
    while [ -n "$1" ]; do
        input_file="${LOG_DIR}/${component_name}/${1}"
        output_file="${OUTPUT_DIR}/${BUILD_TAG}/${component_name}/${1}"
        mkdir -p $(dirname ${output_file})
        if [ -f "${input_file}" ]; then
            cat ${input_file}.1 ${input_file} | awk -- "${program}" > "${output_file}"
            #gzip "${output_file}"
        fi
        shift
    done
}

for component in $os_components; do
    case $component in
        heat)
            split_logs heat heat-api.log heat-engine.log
        ;;
        nova)
            split_logs nova nova-api.log nova-compute.log
        ;;
        keystone)
            split_logs keystone keystone.log
        ;;
        neutron)
            split_logs neutron server.log
        ;;
        *)
            echo "'$component' not valid component!"
        ;;
    esac
done
