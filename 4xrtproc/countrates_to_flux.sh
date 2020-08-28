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

(
  # Here we take the countrates measurements from the last block,
  # saved in file '$COUNTRATES_TABLE', which are in units of `cts/s`,
  # and transform them to energy flux, in `erg/s/cm2`.
  # We will use Paolo's countrates code, which takes the integrated
  # (photon) flux, energy slope and transform it accordingly.
  #
  BLOCK='COUNTRATES_TO_FLUX'
  print "# Block (5) $BLOCK"
  cd $OUTDIR

  source ${SCRPT_DIR}/countrates.sh

  FLUX_TABLE="${OUTDIR}/table_flux_detections.csv"
  EVENTSSUM_RESULT="${OUTDIR}/${RUN_LABEL}_sum.evt"

  # For each detected source (each source is read from COUNTRATES_TABLE)
  # get its NH (given RA and DEC read from COUNTRATES_TABLE, use 'nh' tool)
  # define the middle band values (soft:0.5, medium:1.5, hard:5)
  # get the slope from swiftslope.py
  # input them all to 'countrates' to get nuFnu
  print "# -> Converting objects' countrates to flux.."

  echo -n "#RA;DEC;NH;ENERGY_SLOPE;ENERGY_SLOPE_ERROR;EXPOSURE_TIME"                                   > $FLUX_TABLE
  echo -n ";nufnu_3keV(erg.s-1.cm-2);nufnu_error_3keV(erg.s-1.cm-2)"                                          >> $FLUX_TABLE
  echo -n ";nufnu_0.5keV(erg.s-1.cm-2);nufnu_error_0.5keV(erg.s-1.cm-2);upper_limit_0.5keV(erg.s-1.cm-2)"       >> $FLUX_TABLE
  echo -n ";nufnu_1.5keV(erg.s-1.cm-2);nufnu_error_1.5keV(erg.s-1.cm-2);upper_limit_1.5keV(erg.s-1.cm-2)" >> $FLUX_TABLE
  echo -n ";nufnu_4.5keV(erg.s-1.cm-2);nufnu_error_4.5keV(erg.s-1.cm-2);upper_limit_4.5keV(erg.s-1.cm-2)"       >> $FLUX_TABLE
  echo    ";MJD_OBS;TELAPSE" >> $FLUX_TABLE

  # Let's add information about the epoch of the observations;
  # Because the product of the pipeline is the integrated photometry
  # of all observations, the initial MJD and Elapsed time will be given
  # accordingly, from the stacked image.
  MJD_OBS=$(fkeyprint ${EVENTSSUM_RESULT}+1 'mjd-obs' | grep "MJD-OBS =" | awk '{print $3}')
  TELAPSE=$(fkeyprint ${EVENTSSUM_RESULT}+1 'telapse' | grep "TELAPSE =" | awk '{print $3}')

  IFS=';' read -a HEADER <<< `head -n1 $COUNTRATES_TABLE`
  print "Countrates table/input:"
  print "${HEADER[@]}"

  for DET in `tail -n +2 $COUNTRATES_TABLE`; do
    IFS=';' read -a FIELDS <<< "${DET}"
    print "${FIELDS[@]}"

    # RA and Dec are the first two columns (in COUNTRATES_TABLE);
    # they are colon-separated, which we have to substitute by spaces
    #
    RA=${FIELDS[0]}
    DEC=${FIELDS[1]}
    coords=$(bash ${SCRPT_DIR}/sex2deg.sh "$RA" "$DEC" | tail -n1)
    ra=$(echo $coords | cut -d' ' -f1)
    dec=$(echo $coords | cut -d' ' -f2)

    # NH comes from ftool's `nh` tool
    #
    NH=$(nh 2000 $ra $dec | tail -n1 | awk '{print $NF}')
    print -n "    RA=$RA DEC=$DEC NH=$NH"

    # Countrates:
    #
    CT_FULL=${FIELDS[2]}
    CT_FULL_ERROR=${FIELDS[3]}
    #
    EXPTIME=${FIELDS[4]}
    print -n " EXPTIME=$EXPTIME"
    #
    CT_SOFT=${FIELDS[5]}
    CT_SOFT_ERROR=${FIELDS[6]}
    CT_SOFT_UL=${FIELDS[7]}
    #
    CT_MEDIUM=${FIELDS[8]}
    CT_MEDIUM_ERROR=${FIELDS[9]}
    CT_MEDIUM_UL=${FIELDS[10]}
    #
    CT_HARD=${FIELDS[11]}
    CT_HARD_ERROR=${FIELDS[12]}
    CT_HARD_UL=${FIELDS[13]}

    # The `Swifslope` tool computes the slope of flux between hard(2-10keV)
    # and soft(0.3-2keV) bands. It's soft band definition comprises
    # *our* soft+medium (0.3-1keV + 1-2keV) definition.
    # That's why we are adding the soft+medium fluxes
    ct_softium=$(echo "$CT_SOFT $CT_MEDIUM" | awk '{print $1 + $2}')
    ct_softium_error=$(echo "$CT_SOFT_ERROR $CT_MEDIUM_ERROR" \
      | awk '{s=$1; m=$2; if(s<0){s=0}; if(m<0){m=0}; print( sqrt(s*s + m*m) )}')

    ENERGY_SLOPE=$(${SCRPT_DIR}/swiftslope.py --nh=$NH \
                                        --soft=$ct_softium \
                                        --soft_error=$ct_softium_error \
                                        --hard=$CT_HARD \
                                        --hard_error=$CT_HARD_ERROR \
                                        --oneline)
    ENERGY_SLOPE_minus=$(echo $ENERGY_SLOPE | cut -d' ' -f3)
    ENERGY_SLOPE_plus=$(echo $ENERGY_SLOPE | cut -d' ' -f2)
    ENERGY_SLOPE=$(echo $ENERGY_SLOPE | cut -d' ' -f1)
    SLOPE_OK=$(echo "$ENERGY_SLOPE" | awk '{if($1==-99){print "no"}else{print "yes"}}')
    if [[ $SLOPE_OK == 'no' ]];
    then
      ENERGY_SLOPE_minus=${NULL_VALUE}
      ENERGY_SLOPE_plus=${NULL_VALUE}
      ENERGY_SLOPE='0.8'
      # print " # ENERGY_SLOPE was changed because estimate error was too big (>0.8)"
    fi
    if [[ $SLOPE_OK == 'yes' ]];
    then
      SLOPE_OK=$(echo "$ENERGY_SLOPE_plus $ENERGY_SLOPE_minus" | awk '{dif=$1-$2; if(dif<0.5){print "yes"}else{print "no"}}')
      if [[ $SLOPE_OK == 'no' ]];
      then
        ENERGY_SLOPE_minus=${NULL_VALUE}
        ENERGY_SLOPE_plus=${NULL_VALUE}
        ENERGY_SLOPE='0.8'
        # print " # ENERGY_SLOPE was changed because estimate error was too big (>0.8)"
      fi
    fi
    print " ENERGY_SLOPE=$ENERGY_SLOPE"

    for BAND in `energy_bands list`; do
      # echo "#  -> Running band: $BAND"
      NUFNU_FACTOR=$(run_countrates $BAND $ENERGY_SLOPE $NH)
      print "      BAND=$BAND NUFNU_FACTOR=$NUFNU_FACTOR"
      case $BAND in
        soft)
          FLUX_SOFT=$(echo "$NUFNU_FACTOR $CT_SOFT" | awk '{print $1*$2}')
          FLUX_SOFT_ERROR=$(echo "$NUFNU_FACTOR $CT_SOFT_ERROR" | awk '{print $1*$2}')
          if [ $(is_null $CT_SOFT_UL) == 'yes' ]; then
            FLUX_SOFT_UL=$CT_SOFT_UL
          else
            FLUX_SOFT_UL=$(echo "$NUFNU_FACTOR $CT_SOFT_UL" | awk '{print $1*$2}')
          fi
          print "      FLUX_SOFT=$FLUX_SOFT FLUX_SOFT_ERROR=$FLUX_SOFT_ERROR FLUX_SOFT_UL=$FLUX_SOFT_UL"
          ;;
        medium)
          FLUX_MEDIUM=$(echo "$NUFNU_FACTOR $CT_MEDIUM" | awk '{print $1*$2}')
          FLUX_MEDIUM_ERROR=$(echo "$NUFNU_FACTOR $CT_MEDIUM_ERROR" | awk '{print $1*$2}')
          if [ $(is_null $CT_MEDIUM_UL) == 'yes' ]; then
            FLUX_MEDIUM_UL=$CT_MEDIUM_UL
          else
            FLUX_MEDIUM_UL=$(echo "$NUFNU_FACTOR $CT_MEDIUM_UL" | awk '{print $1*$2}')
          fi
          print "      FLUX_MEDIUM=$FLUX_MEDIUM FLUX_MEDIUM_ERROR=$FLUX_MEDIUM_ERROR FLUX_MEDIUM_UL=$FLUX_MEDIUM_UL"
          ;;
        hard)
          FLUX_HARD=$(echo "$NUFNU_FACTOR $CT_HARD" | awk '{print $1*$2}')
          FLUX_HARD_ERROR=$(echo "$NUFNU_FACTOR $CT_HARD_ERROR" | awk '{print $1*$2}')
          if [ $(is_null $CT_HARD_UL) == 'yes' ]; then
            FLUX_HARD_UL=$CT_HARD_UL
          else
            FLUX_HARD_UL=$(echo "$NUFNU_FACTOR $CT_HARD_UL" | awk '{print $1*$2}')
          fi
          print "      FLUX_HARD=$FLUX_HARD FLUX_HARD_ERROR=$FLUX_HARD_ERROR FLUX_HARD_UL=$FLUX_HARD_UL"
          ;;
        full)
          FLUX_FULL=$(echo "$NUFNU_FACTOR $CT_FULL" | awk '{print $1*$2}')
          FLUX_FULL_ERROR=$(echo "$NUFNU_FACTOR $CT_FULL_ERROR" | awk '{print $1*$2}')
          print "      FLUX_FULL=$FLUX_FULL FLUX_FULL_ERROR=$FLUX_FULL_ERROR"
          ;;
      esac
    done
    ENERGY_SLOPE_ERROR="${ENERGY_SLOPE_plus}/${ENERGY_SLOPE_minus}"
    echo -n "${RA};${DEC};${NH};${ENERGY_SLOPE};${ENERGY_SLOPE_ERROR}">> $FLUX_TABLE
    echo -n ";${EXPTIME}"                                              >> $FLUX_TABLE
    echo -n ";${FLUX_FULL};${FLUX_FULL_ERROR}"                        >> $FLUX_TABLE
    echo -n ";${FLUX_SOFT};${FLUX_SOFT_ERROR};${FLUX_SOFT_UL}"        >> $FLUX_TABLE
    echo -n ";${FLUX_MEDIUM};${FLUX_MEDIUM_ERROR};${FLUX_MEDIUM_UL}"  >> $FLUX_TABLE
    echo -n ";${FLUX_HARD};${FLUX_HARD_ERROR};${FLUX_HARD_UL}"        >> $FLUX_TABLE
    echo    ";${MJD_OBS};${TELAPSE}" >> $FLUX_TABLE
  done
  sed -i.bak 's/[[:space:]]/;/g' $FLUX_TABLE
  print "#..............................................................."
)
