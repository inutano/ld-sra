#!/bin/sh
set -eux

# The path to the directory to where the DRA storage attached
FASTQ_DIR="/usr/local/resources/dra/fastq"

# The path to the directories
BASE_DIR="/home/inutano/repos/ld-sra"
RESULT_DIR="${BASE_DIR}/data"
WORK_DIR="${RESULT_DIR}/$(date "+%Y%m%d")"
JOBCONF_DIR="${WORK_DIR}/jobconf"
TTL_DIR="${WORK_DIR}/ttl"
mkdir -p "${JOBCONF_DIR}" "${TTL_DIR}"

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
  find ${dir} -name '*ttl' | xargs cat > ./${dir}.ttl
done
