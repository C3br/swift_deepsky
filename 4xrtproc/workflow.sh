#!/usr/bin/env bash
set -ue

SCRPT_DIR=$(cd `dirname $BASH_SOURCE`; pwd)

help() {
  echo ""
  echo " Usage: $(basename $0) <crates-table> <outdir> <label>"
  echo ""
}

# If no arguments given, print Help and exit.
[ "${#@}" -eq 0 ] && { help; exit 0; }

COUNTRATES_TABLE="$1"
OUTDIR="$2"
RUN_LABEL="$3"

#1 abbiamo sosta log
CTS_SOST_FULL="${TMPDIR}/countrates_full.sosta.txt"
python ${SCRPT_DIR}/module_Sosta_log_to_table.py $LOGFILE_FULL '0.3-10keV' > $CTS_SOST_FULL

CTS_SOST_SOFT="${TMPDIR}/countrates_soft.sosta.txt"
python ${SCRPT_DIR}/module_Sosta_log_to_table.py $LOGFILE_SOFT '0.3-1keV' > $CTS_SOST_SOFT

CTS_SOST_MEDIUM="${TMPDIR}/countrates_medium.sosta.txt"
python ${SCRPT_DIR}/module_Sosta_log_to_table.py $LOGFILE_MEDIUM '1-2keV' > $CTS_SOST_MEDIUM

CTS_SOST_HARD="${TMPDIR}/countrates_hard.sosta.txt"
python ${SCRPT_DIR}/module_Sosta_log_to_table.py $LOGFILE_HARD '2-10keV' > $CTS_SOST_HARD

#2 sistemiamo countrates
COUNTRATES_SOSTA_TABLE="sosta.log.csv"
paste $CTS_DET_FULL \
      $CTS_SOST_FULL \
      $CTS_SOST_SOFT \
      $CTS_SOST_MEDIUM \
      $CTS_SOST_HARD \
      > $COUNTRATES_SOSTA_TABLE

tail -n +2 $COUNTRATES_SOSTA_TABLE \
  | awk -f ${SCRPT_DIR}/module_Sosta_adjust_countrates.awk > $COUNTRATES_TABLE

#3 countrates to flux
${SCRPT_DIR}/countrates_to_flux.sh $COUNTRATES_TABLE $OUTPUT $RUN_LABEL
