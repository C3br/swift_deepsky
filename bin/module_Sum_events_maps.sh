#!/usr/bin/env bash
set +u

source $SCRPT_DIR/compute_baricenter.sh

is_eventsfile_good(){
    # check if file is good to use;
    # Return '0' if it's good to go
    FILE="$1"
    [ -f "$FILE" ] || return 2
    return 0
}

is_eventsfile_in_radius() {
    local FILE="$1"
    local CENTER="$2"
    local RADIUS="$3"

    local RAo=$(echo $CENTER | cut -d',' -f1)
    local DECo=$(echo $CENTER | cut -d',' -f2)

    local RAf=$(read_ra $FILE)
    local DECf=$(read_dec $FILE)

    python ${SCRPT_DIR}/check_distance.py $RAo $DECo $RAf $DECf $RADIUS
    return $?
}

select_event_files(){
  local DATA_ARCHIVE="$1"
  local OBS_ADDR_LIST="$2"
  local RADIUS="$3"
  local OUT_FILE="$4"


  # Files succeeding the filtering
  # 1) *xpc*po_cl.evt.gz
  # 2) pointing (RA_PNT,DEC_PNT) within RADIUS
  # 3) copy files selected to local/tmp dir

  local OUT_FILE_TMP="${OUT_FILE}.tmp"

  local SWIFT_OBS_ARCHIVE="${DATA_ARCHIVE}"

  local TMPXRT="${TMPDIR}/xrt"
  mkdir -p $TMPXRT

  for ln in `cat $OBS_ADDR_LIST`
  do
    OIFS=$IFS
    IFS='/' read -ra FLDS <<< "$ln"
    IFS=$OIFS
    DATADIR="${SWIFT_OBS_ARCHIVE}/${FLDS[0]}/${FLDS[1]}"
    [ -d $DATADIR ] || continue
    XRTDIR=${DATADIR}/xrt
    EVTDIR=${XRTDIR}/event

    for f in ${EVTDIR}/*xpc*po_cl.evt.gz; do
      if [ -e "$f" ]; then
        echo "$f" >> $OUT_FILE_TMP
      fi
    done
    # for f in ${EVTDIR}/*xpc*po_cl.evt.gz; do
    #   is_eventsfile_good "$f" || continue
    #   _fn="${TMPXRT}/${f##*/}"
    #   if [ -e "$f" ]; then
    #     cp ${f} ${_fn}
    #     cp -R "${DATADIR}/auxil" "${TMPDIR}/."
    #     cp -R "${XRTDIR}/hk" "${TMPXRT}/."
    #     echo "$_fn" >> $OUT_FILE
    #   else
    #     1>&2 echo "Files not found for observation: $f"
    #     break
    #   fi
    # done
  done

  local CENTER=$(compute_baricenter $OUT_FILE_TMP)

  for f in `cat $OUT_FILE_TMP`
  do
      is_eventsfile_in_radius $f $CENTER $RADIUS || continue
    DATADIR="${f%/xrt/event/*}"
    XRTDIR="${DATADIR}/xrt"
      _fn="${TMPXRT}/${f##*/}"
      cp ${f} ${_fn}
      cp -R "${DATADIR}/auxil" "${TMPDIR}/."
      cp -R "${XRTDIR}/hk" "${TMPXRT}/."
      echo "$_fn" >> $OUT_FILE
  done

  cat "${OUT_FILE}" | sort -n > "${OUT_FILE_TMP}"
  mv "${OUT_FILE_TMP}" "${OUT_FILE}"
}

select_exposure_maps() {
  # DATA_ARCHIVE="$1"
  local EXPDIR="$1"
  local OBS_ADDR_LIST="$2"
  local OUT_FILE="$3"

  # SWIFT_OBS_ARCHIVE="${DATA_ARCHIVE}"

  # for ln in `cat $OBS_ADDR_LIST`
  # do
  #   OIFS=$IFS
  #   IFS='/' read -ra FLDS <<< "$ln"
  #   IFS=$OIFS
  #   # DATADIR="${SWIFT_OBS_ARCHIVE}/${FLDS[0]}/${FLDS[1]}"
  #   # [ -d $DATADIR ] || continue
  #   # XRTDIR=${DATADIR}/xrt
  #   # EXPDIR=${XRTDIR}/products

    for f in ${EXPDIR}/*xpc*po_ex.img*; do
      _fn="${TMPDIR}/${f##*/}"
      if [ -e "$f" ]; then
        cp ${f} ${_fn}
        echo "$_fn" >> $OUT_FILE
      else
        1>&2 echo "Files not found for observation: $f"
        break
      fi
      # if [ -e "$f" ]; then
      #   echo "$f" >> $OUT_FILE
      # else
      #   1>&2 echo "Files not found for observation: $ln"
      #   break
      # fi
    done
  # done
  cat "${OUT_FILE}" | sort -n > "${OUT_FILE}.tmp"
  mv "${OUT_FILE}.tmp" "${OUT_FILE}"
}

create_xselect_sum_script() {
  NAME="$1"
  EVTLIST="$2"
  RESULT="$3"
  OUT_FILE="$4"
  CENTER="$5"

  RA=$(echo $CENTER | cut -d',' -f1)
  DEC=$(echo $CENTER | cut -d',' -f2)

  TMPDIRREL="./${TMPDIR#$PWD}/xrt"

  NAME=$(echo $NAME | tr -c "[:alnum:]\n" "_")

  read -a EVTFILES <<< `grep -v "^#" ${EVTLIST}`
  NUMEVTFILES=${#EVTFILES[@]}

  echo "xsel"                                 >> $OUT_FILE
  # echo "log ${TMPDIR}/xselect_eventssum.log"

  i=0
  _FILE=${EVTFILES[$i]##*/}
  # cp ${EVTFILES[$i]} "${TMPDIR}/${_FILE}"
  echo "read/ra=${RA}/dec=${DEC} ev $_FILE"                       >> $OUT_FILE
  echo "${TMPDIRREL}/"                        >> $OUT_FILE
  echo "yes"                                  >> $OUT_FILE
  for ((i=1; i<$NUMEVTFILES; i++)); do
    _FILE=${EVTFILES[$i]##*/}
    # cp ${EVTFILES[$i]} "${TMPDIR}/${_FILE}"
    echo "read/ra=${RA}/dec=${DEC} ev $_FILE"                     >> $OUT_FILE
    if [ $i -ge 19 ]; then
      echo 'yes'                              >> $OUT_FILE
    fi
  done
  echo 'extract ev'                           >> $OUT_FILE
  echo "save ev $RESULT"                      >> $OUT_FILE
  echo "yes"                                  >> $OUT_FILE
  echo "quit"                                 >> $OUT_FILE
  echo "no"                                   >> $OUT_FILE
}

create_ximage_sum_script() {
  NAME="$1"
  IMGLIST="$2"
  RESULT="$3"
  OUT_FILE="$4"
  CENTER="$5"

  RA=$(echo $CENTER | cut -d',' -f1)
  DEC=$(echo $CENTER | cut -d',' -f2)

  TMPDIRREL="./${TMPDIR#$PWD}/expomaps"

  NAME=$(echo $NAME | tr -c "[:alnum:]\n" "_")

  read -a IMAGES <<< `grep -v "^#" $IMGLIST`
  NUMIMAGES=${#IMAGES[@]}

  # echo "log ${TMPDIR}/ximage_expossum.log"
  echo "cpd ${NAME}_sum.exposure.gif/gif"        >> $OUT_FILE

  i=0
  _FILE=${IMAGES[$i]##*/}
  _FILE=${TMPDIRREL}/${_FILE}
  # cp ${IMAGES[$i]} "${_FILE}"
  echo "read/size=800/ra=${RA}/dec=${DEC} ${_FILE}" >> $OUT_FILE
  for ((i=1; i<$NUMIMAGES; i++)); do
    _FILE=${IMAGES[$i]##*/}
    _FILE=${TMPDIRREL}/${_FILE}
    # cp ${IMAGES[$i]} "${_FILE}"
    echo "read/size=800/ra=${RA}/dec=${DEC} ${_FILE}" >> $OUT_FILE
    echo 'sum_image'                              >> $OUT_FILE
    echo 'save_image'                             >> $OUT_FILE
  done
  echo "display"                                  >> $OUT_FILE
  echo "write_ima/template=all/file=\"$RESULT\""  >> $OUT_FILE
  echo "exit"                                     >> $OUT_FILE
}
