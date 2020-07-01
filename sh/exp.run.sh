#!/bin/bash
# set -eux

# Path to the directory DRA storage mounted
[[ -z ${FASTQ_DIR} ]] && FASTQ_DIR="/usr/local/resources/dra/fastq"
printf "Use ${FASTQ_DIR} for XML source..\n"

# Path to job script
JOB_SCRIPT_PATH="$(cd $(dirname $0) && pwd -P)/exp.job.sh"

# Path to working directories
if [[ -z ${1} ]]; then
  WORKDIR="$(cd $(dirname $0) && pwd -P)/../data/$(date "+%Y%m%d")"
else
  mkdir -p "${1}"
  WORKDIR="$(cd ${1} && pwd -P)"
fi

JOBCONF_DIR="${WORKDIR}/jobconf"; mkdir -p "${JOBCONF_DIR}"
TTL_DIR="${WORKDIR}/ttl";         mkdir -p "${TTL_DIR}"
# UGE_LOG_DIR="${WORKDIR}/log";     mkdir -p "${UGE_LOG_DIR}" # For debug

ttl_prefixes() {
  cat <<EOS
@prefix : <http://bio.cow/ontology/sra-experiement/> .
@prefix id: <http://identifiers.org/insdc.sra/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dct: <http://purl.obolibrary.org/obo/> .

EOS
}

# Create array job configuration
if [[ -z $(find ${JOBCONF_DIR} -name 'exp.*') ]]; then
  cd ${JOBCONF_DIR}
  find ${FASTQ_DIR} -type f -name '*.experiment.xml' | split -l 5000 -d - "exp."
fi

# Load UGE settings
source "/home/geadmin/UGED/uged/common/settings.sh"

# Execute array job
find ${JOBCONF_DIR} -name "exp.*" | sort | while read jobconf; do
  qsub -N "$(basename ${jobconf})" \
    -j y \
    -o /dev/null \
    -pe def_slot 1 -l s_vmem=4G -l mem_req=4G \
    -t 1-$(wc -l "${jobconf}" | awk '$0=$1'):1 \
    ${JOB_SCRIPT_PATH} ${jobconf} ${TTL_DIR}
done

# Wait until the all jobs complete
while :; do
  sleep 30
  running_jobs=$(qstat | grep "exp.")
  if [[ -z ${running_jobs} ]]; then
    printf "All jobs finished.\n"
    break
  fi
done

# Assemble the ttl files by the accession number group
find "${TTL_DIR}" -maxdepth 1 -name '*RA*' -type d | while read dir; do
  cat <(ttl_prefixes) <(find ${dir} -name '*ttl' | xargs cat) > "${TTL_DIR}/$(basename ${dir}).ttl"
  # rm -fr ${dir}
done
