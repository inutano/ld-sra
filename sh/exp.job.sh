#!/bin/sh
#$ -S /bin/sh -j y
set -eux

# Load rbenv
export PATH="/home/inutano/.rbenv/bin:${PATH}"
eval "$(rbenv init -)"

# ARGS
EXP_XML_PATH=$(awk -v id=${SGE_TASK_ID} 'NR == id { print $0 }' ${1})
ACC=$(basename ${EXP_XML_PATH} .experiment.xml)

# Path to directories
BASE_DIR="/home/inutano/repos/ld-sra"
TTL_DIR=${2}
DEST_DIR="${TTL_DIR}/${ACC:0:6}/${ACC}"
ttl_path="${DEST_DIR}/${ACC}.experiment.ttl"

# run xml2ttl
if [[ ! -e "${ttl_path}" ]]; then
  mkdir -p "${DEST_DIR}"
  ${BASE_DIR}/xml2ttl experiment ${EXP_XML_PATH} |\
    grep -v "^@prefix" > "${ttl_path}"
fi
