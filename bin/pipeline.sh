#!/usr/bin/env bash
set -ue

SCRPT_DIR=$(cd `dirname $BASH_SOURCE`; pwd)

########################################################################
# Swift-Events stacking
# =====================
# Input:
# - Swift Master table
# - Object name or position
# - Root data archive directory
# Output:
#
#
# Swift Master table
# ------------------
# This is a CSV (sep=';') table where each row contains information
# about Swift observations. The table must contain the columns: 'OBSID',
# 'START_TIME','RA','DEC'.
#
# Object name or position
# -----------------------
# If an object name is given, the corresponding position, as published
# by Vizier/SIMBAD, will be retrieved. The position is used as the
# central coordinate from where a cone-search is performed using a
# 12 arcmin search radius throught the entire Swift Master table.
# All observations falling inside the region will be processed.
#
# Root data archive directory
# ---------------------------
# The directory where 'swift' archive tree is stored. Observational
# data will there be searched; If not there yet, it is downloaded.
#
########################################################################
help() {
  echo ""
  echo " Usage: $(basename $0) -f <swift_table.csv> -s <object_name> -d <swift_archive>"
  echo ""
  echo " Options:"
  echo "  -h : this help message"
  echo "  -d : root data archive directory (where 'swift' directories tree is)"
  echo "  -f : Swift master table"
  echo "  -o : output directory; default is the current directory"
  echo "  -s : name of object to select"
  echo "  -v : verbose"
  echo ""
  exit 0
}
trap help ERR

[ "${#@}" -eq 0 ] && help

OUTDIR="$PWD"

while getopts ":hqs:f:d:o:" opt; do
  case $opt in
    h) help;;
    v) VERBOSE=1;;
    s) OBJECT="$OPTARG";;
    f) TABLE_MASTER="$OPTARG";;
    d) DATA_ARCHIVE="$OPTARG";;
    o) OUTDIR="$OPTARG";;
    \?) echo "ERROR: Wrong option $OPTARG ";;
    :) echo "ERROR: Missing value for $OPTARG ";;
  esac
done

: ${TABLE_MASTER:?'Argument -f must be specified'}
: ${OBJECT:?'Argument -s must be specified'}
: ${DATA_ARCHIVE:?'Argument -d must be specified'}

# Guarantee input (table and data) files are in absolute-path format
#
[[ "${TABLE_MASTER}" = /* ]] || TABLE_MASTER="${PWD}/${TABLE_MASTER}"
[[ "${DATA_ARCHIVE}" = /* ]] || DATA_ARCHIVE="${PWD}/${DATA_ARCHIVE}"
[[ "${OUTDIR}" = /* ]] || OUTDIR="${PWD}/${OUTDIR}"

# Normalize object name to remove non-alphanumeric characters
#
OBJNAME_NORMALIZED=$(echo $OBJECT | tr -d '[:space:].' | tr "+" "p" | tr "-" "m")

# Output and temporary directories to store averything accordingly
#
OUTDIR="${OUTDIR}/${OBJNAME_NORMALIZED}"
TMPDIR="${OUTDIR}/tmp"

if [ -d $OUTDIR ]; then
  touch ${OUTDIR}/bla.tmp
  rm ${OUTDIR}/*.*
  rm -rf ${TMPDIR}
else
  mkdir -p ${OUTDIR}
fi
[ -d $TMPDIR ] || mkdir -p ${TMPDIR}


# List of Swift archive observation addresses
#
OBSLIST="${TMPDIR}/${OBJNAME_NORMALIZED}.archive_addr.txt"
(
  BLOCK='INTRO'
  cd $OUTDIR

  # Swift table selected entries file
  #
  TABLE_OBJECT="${OUTDIR}/${OBJNAME_NORMALIZED}_observations.csv"

  # Select rows/obserations from master table that contain OBJECT
  #
  python ${SCRPT_DIR}/select_observations.py $TABLE_MASTER \
                                            $TABLE_OBJECT \
                                            --object "$OBJECT" \
                                            --archive_addr_list $OBSLIST
  [[ $? -eq 0 ]] || { 1>&2 echo "Exiting."; exit; }

  # Download Swift observations; Already present datasets are skipped
  #
  ${SCRPT_DIR}/download_queue.sh -n 10 -f $OBSLIST -d $DATA_ARCHIVE

)

XSELECT_RESULT="${OUTDIR}/${OBJNAME_NORMALIZED}_sum.evt"
XIMAGE_RESULT="${OUTDIR}/${OBJNAME_NORMALIZED}_sum.exp"
(
  BLOCK='DATA_SUM'
  cd $OUTDIR

  source ${SCRPT_DIR}/setup_ximage_files.fsh

  # Create two files with filenames list of event-images and exposure-maps
  #
  EVENTSFILE="${TMPDIR}/${OBJNAME_NORMALIZED}_events.txt"
  event_files $DATA_ARCHIVE $OBSLIST > $EVENTSFILE

  EXMAPSFILE="${TMPDIR}/${OBJNAME_NORMALIZED}_expos.txt"
  exposure_maps $DATA_ARCHIVE $OBSLIST > $EXMAPSFILE

  # Create XSelect and XImage scripts to sum event-files and exposure-maps
  #
  XSELECT_SUM_SCRIPT="${TMPDIR}/events_sum.xcm"
  create_xselect_script $OBJNAME_NORMALIZED $EVENTSFILE $XSELECT_RESULT > $XSELECT_SUM_SCRIPT

  XIMAGE_SUM_SCRIPT="${TMPDIR}/expos_sum.xco"
  create_ximage_script $OBJNAME_NORMALIZED $EXMAPSFILE $XIMAGE_RESULT > $XIMAGE_SUM_SCRIPT

  # Run the scripts
  #
  xselect < $XSELECT_SUM_SCRIPT
  ximage < $XIMAGE_SUM_SCRIPT
)

XSELECT_DET_DEFAULT="${XSELECT_RESULT%.*}.det"
XSELECT_DET_FULL="${XSELECT_RESULT%.*}.full.det"
XSELECT_DET_SOFT="${XSELECT_RESULT%.*}.soft.det"
XSELECT_DET_HARD="${XSELECT_RESULT%.*}.hard.det"
(
  BLOCK='DETECT'
  cd $OUTDIR

  XIMAGE_TMP_SCRIPT="${TMPDIR}/ximage.xco"

  cat > $XIMAGE_TMP_SCRIPT << EOF
read/size=1024 $XSELECT_RESULT
read/size=1024/expo $XIMAGE_RESULT
det/bright
quit
EOF
  ximage < $XIMAGE_TMP_SCRIPT
  mv $XSELECT_DET_DEFAULT $XSELECT_DET_FULL

  cat > $XIMAGE_TMP_SCRIPT << EOF
read/size=1024/ecol=PI/emin=30/emax=200 $XSELECT_RESULT
read/size=1024/expo $XIMAGE_RESULT
det/bright
quit
EOF
  ximage < $XIMAGE_TMP_SCRIPT
  mv $XSELECT_DET_DEFAULT $XSELECT_DET_SOFT

  cat > $XIMAGE_TMP_SCRIPT << EOF
read/size=1024/ecol=PI/emin=201/emax=1000 $XSELECT_RESULT
read/size=1024/expo $XIMAGE_RESULT
det/bright
quit
EOF
  ximage < $XIMAGE_TMP_SCRIPT
  mv $XSELECT_DET_DEFAULT $XSELECT_DET_HARD

  rm $XIMAGE_TMP_SCRIPT
)

FINAL_TABLE="${OUTDIR}/table_flux_detections.adjusted.txt"
(
  BLOCK='SOSTA'
  cd $OUTDIR

  source ${SCRPT_DIR}/det2sosta.fsh

  XIMAGE_TMP_SCRIPT="${TMPDIR}/ximage.xco"

  LOGFILE_FULL="${OUTDIR}/sosta_full.log"
  CTS_DET_FULL="${TMPDIR}/countrates_full.detect.txt"
  det2sosta $XSELECT_DET_FULL \
            $XSELECT_DET_FULL 30 1000 \
            $XIMAGE_RESULT \
            $LOGFILE_FULL $CTS_DET_FULL \
            > $XIMAGE_TMP_SCRIPT
  ximage < $XIMAGE_TMP_SCRIPT

  LOGFILE_SOFT="${OUTDIR}/sosta_soft.log"
  CTS_DET_SOFT="${TMPDIR}/countrates_soft.detect.txt"
  det2sosta $XSELECT_DET_FULL \
            $XSELECT_DET_SOFT 30 200 \
            $XIMAGE_RESULT \
            $LOGFILE_SOFT $CTS_DET_SOFT \
            > $XIMAGE_TMP_SCRIPT
  ximage < $XIMAGE_TMP_SCRIPT

  # det2sosta $XSELECT_DET_FULL $XSELECT_DET_HARD 201 1000 $XIMAGE_RESULT > $XIMAGE_TMP_SCRIPT
  LOGFILE_HARD="${OUTDIR}/sosta_hard.log"
  CTS_DET_HARD="${TMPDIR}/countrates_hard.detect.txt"
  det2sosta $XSELECT_DET_FULL \
            $XSELECT_DET_HARD 201 1000 \
            $XIMAGE_RESULT \
            $LOGFILE_HARD $CTS_DET_HARD \
            > $XIMAGE_TMP_SCRIPT
  ximage < $XIMAGE_TMP_SCRIPT

  rm $XIMAGE_TMP_SCRIPT

  CTS_SOST_FULL="${TMPDIR}/countrates_full.sosta.txt"
  python ${SCRPT_DIR}/read_detections.py $LOGFILE_FULL  > $CTS_SOST_FULL
  CTS_SOST_SOFT="${TMPDIR}/countrates_soft.sosta.txt"
  python ${SCRPT_DIR}/read_detections.py $LOGFILE_SOFT  > $CTS_SOST_SOFT
  CTS_SOST_HARD="${TMPDIR}/countrates_hard.sosta.txt"
  python ${SCRPT_DIR}/read_detections.py $LOGFILE_HARD  > $CTS_SOST_HARD

  DETECT_FLUX_TABLE="${OUTDIR}/table_flux_detections.txt"
  paste $CTS_DET_FULL $CTS_SOST_FULL $CTS_SOST_SOFT $CTS_SOST_HARD > $DETECT_FLUX_TABLE

  grep -v "^#" $DETECT_FLUX_TABLE | awk -f ${SCRPT_DIR}/adjust_fluxes.awk > $FINAL_TABLE
)

echo "---"
echo "Pipeline finished. Final table: '$FINAL_TABLE'"
echo "---"
