#!/bin/sh -ue

COMMAND=$(printf ' %q' "$@")
_NAME=$(basename $1)
APP=${_NAME%.*}

USER_TMP_DIR="/run/user/$(id -u)/sway_log"
mkdir -p ${USER_TMP_DIR}

LOG=${USER_TMP_DIR}/${APP}.log

echo "[log_wrapper] Running ${COMMAND}, output log to ${LOG}"

sh -c "${COMMAND}" >> ${LOG} 2>&1 || echo "[log_wrapper] App terminated ${COMMAND}, see log ${LOG}"
