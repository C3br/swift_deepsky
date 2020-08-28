#!/usr/bin/env bash

# This module, in particular the function 'run_countrates' here, is
# defined to interface Paolo's 'countrates', inside the directory equally
# named next to this script.


energy_bands() {
  # This function defines the energy ranges and effective energy for
  # (Swift) x-ray bands ('full','soft','medium','hard')
  #
  # Arguments:
  # $1) BAND is one of 'full','soft','medium','hard'
  # $2) OPTE is 'min','max' or 'eff'
  #     If "$2" is not given, return all values associated with 'BAND'
  #
  # If "$1" is "list", list the energy bands.
  #
  [[ ${#@} -eq 0 ]] && return 1

  local -a ENERGY_BANDS
  ENERGY_BANDS[0]='0.3 3.0 10.0'
  ENERGY_BANDS[1]='0.3 0.5 1.0'
  ENERGY_BANDS[2]='1.0 1.5 2.0'
  ENERGY_BANDS[3]='2.0 4.5 10.0'

  local BAND=$1
  # BAND=${BAND,,}

  # [[ $BAND == list ]] && { echo "${!ENERGY_BANDS[@]}"; return 0; }
  [[ $BAND == list ]] && { echo "full soft medium hard"; return 0; }
  [[ ${#@} -lt 2 ]] && { 1>&2 echo "Wrong number of arguments"; return 0; }
  case $BAND in
    full)
      iBAND=0;;
    soft)
      iBAND=1;;
    medium)
      iBAND=2;;
    hard)
      iBAND=3;;
    *)
      1>&2 echo "Wrong option for band: $BAND"
      return 0;;
  esac


  local OPTE=$2

  read -a VALS <<< "${ENERGY_BANDS[$iBAND]}"
  local VAL
  case $OPTE in
    min) VAL=${VALS[0]};;
    eff) VAL=${VALS[1]};;
    max) VAL=${VALS[2]};;
  esac
  unset VALS
  echo $VAL
}

run_countrates() {
  # Function to './countrates/countrates'.
  # 'countrates' returns the factor necessary to convert countrates to
  # nufnu for a particular instrument (e.g, Swift), x-ray band, sky
  # position and spectral slope.
  #
  # This function automates the choice of instrument parameters given
  # the 'BAND'. With the help of the function 'energy_bands', it feeds
  # 'countrates with the effective energy to use for nufnu.
  #
  # Arguments:
  # 1) BAND : choices are 'full','soft','medium','hard'
  # 2) SLOPE: spectral slope calculated using hard/soft+medium count rates
  # 3) NH   : Hydrogen column at the corresponding line-of-sight
  #
  local BAND=$1
  local SLOPE=$2
  local NH=$3

  local SAT
  case $BAND in
    full)   SAT=25;;
    soft)   SAT=26;;
    medium) SAT=27;;
    hard)   SAT=28;;
  esac

  local EFFE=$(energy_bands $BAND eff)
  local EMIN=$(energy_bands $BAND min)
  local EMAX=$(energy_bands $BAND max)

  (
    cd "${SCRPT_DIR}/countrates"

    CTS_IN=${TMPDIR}/countrates.in
    CTS_OUT="${CTS_IN%.in}.out"

    echo -e "$SAT\n$EMIN $EMAX\n$EFFE\n1\n1\n$SLOPE\n$NH\nemitted\n0" > $CTS_IN

    local NUFNU=$(./countrates < $CTS_IN | grep "nuFnu" | tail -n1 | awk '{print $(NF-1)}')
    echo $NUFNU
  )
}
