#!/bin/bash
# set -eux

# Path to the directory DRA storage mounted
FASTQ_DIR="/usr/local/resources/dra/fastq"

# Path to job script
JOB_SCRIPT_PATH="$(cd $(dirname $0) && pwd -P)/exp.job.sh"

# Path to working directories
if [[ -z ${1} ]]; then
  WORKDIR="$(cd $(dirname $0) && pwd -P)/../data/$(date "+%Y%m%d")"
else
  mkdir -p "${1}"
  WORKDIR="$(cd ${1} && pwd -P)"
fi

JOBCONF_DIR="${WORKDIR}/jobconf"
TTL_DIR="${WORKDIR}/ttl"
mkdir -p "${JOBCONF_DIR}" "${TTL_DIR}"

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
  cd ${JOBCONF_DIR} && \
    find ${FASTQ_DIR} -name '*.experiment.xml' |\
    split -l 5000 -d - "exp."
fi

# Load UGE settings
source "/home/geadmin/UGED/uged/common/settings.sh"

# Execute array job
find ${JOBCONF_DIR} -name "exp.*" | sort | while read jobconf; do
  jobname=$(basename ${jobconf})
  qsub -N "${jobname}" -o /dev/null -pe def_slot 1 -l s_vmem=4G -l mem_req=4G -t 1-5000:1 \
    ${BASE_DIR}/sh/exp.job.sh ${jobconf} ${TTL_DIR}
done

# Wait until the all jobs complete
while [[ ! -z $(qstat | grep "exp.") ]]; do
  sleep 10
done

# Assemble the ttl files by the accession number group
cd "${TTL_DIR}" && ls -d *RA* | while read dir; do
  cat <(ttl_prefixes) <(find ${dir} -name '*ttl' | xargs cat) > ./${dir}.ttl
done
