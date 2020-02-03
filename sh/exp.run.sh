#!/bin/sh
set -eux

# The path to the directory to where the DRA storage attached
FASTQ_DIR="/usr/local/resources/dra/fastq"

# The path to the directories
BASE_DIR="$(cd $(dirname ${0}) && pwd -P)/.."
RESULT_DIR="${BASE_DIR}/data"
WORK_DIR="${RESULT_DIR}/$(date "+%Y%m%d")"
mkdir -p "${WORK_DIR}"

# Create array job configuration
cd ${WORK_DIR} && \
  find ${FASTQ_DIR} -name '*.experiment.xml' |\
  split -l 5000 -d - "exp.array."

# Load UGE settings
source "/home/geadmin/UGED/uged/common/settings.sh"

# Execute array job
cd ${WORK_DIR} && ls "array.*" | sort | while read jobconf; do
  qsub -j y -N "${jobconf}" -o ${WORK_DIR} -pe def_slot 1 -l s_vmem=4G -l mem_req=4G -t 1-5000:1 \
    ${BASE_DIR}/sh/exp.job.sh ${jobconf}
done
