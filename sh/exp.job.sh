#!/bin/sh
#$ -S /bin/sh -j y
set -eux
module load docker

# Load rbenv
export PATH="/home/inutano/.rbenv/bin:${PATH}"
eval "$(rbenv init -)"

# ARGS
EXP_XML_PATH=$(awk -v id=${SGE_TASK_ID} 'NR == id { print $0 }' ${1})
ACC=$(basename ${EXP_XML_PATH} .experiment.xml)

# Path to directories
OUTDIR="${2}/${ACC:0:6}/${ACC}"
mkdir -p "${OUTDIR}"

TMPDIR="/data1/tmp/biosample-lod/experiment/ttl"
tmp_ttl_path="${TMPDIR}/${ACC:0:6}/${ACC}/${ACC}.experiment.ttl"

# run xml2ttl
mkdir -p $(dirname ${tmp_ttl_path})
docker run --security-opt seccomp=unconfined --rm \
  -v $(dirname ${EXP_XML_PATH}):/work \
  -w /work \
  "quay.io/inutano/ld-sra:v1.0" \
  xml2ttl \
  experiment \
  $(basename ${EXP_XML_PATH}) | grep -v "^@prefix" > "${tmp_ttl_path}"

#
# Validate ttl
#
validation_output="${tmp_ttl_path}.validation"
valid_value='Validator finished with 0 warnings and 0 errors.'

docker run --security-opt seccomp=unconfined --rm \
  -v $(dirname "${tmp_ttl_path}"):/work \
  "quay.io/inutano/turtle-validator:v1.0" \
  ttl \
  /work/$(basename "${tmp_ttl_path}") \
  > "${validation_output}"

if [[ $(cat "${validation_output}") == "${valid_value}" ]]; then
  rm -f "${validation_output}"
else
  mv "${validation_output}" ${OUTDIR}
fi

mv ${tmp_ttl_path} ${OUTDIR}
