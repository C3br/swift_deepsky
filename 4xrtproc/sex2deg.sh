#!/usr/bin/env bash

usage() {
  echo ""
  echo " Convert sexagesimal coordinates to degrees"
  echo " Usage:"
  echo "  $(basename $BASH_SOURCE) <ra> <dec>"
  echo ""
  echo " Note:"
  echo "  Values for 'ra' and 'dec' are expected to be strings without whitespaces in."
  echo "  Either, '00h11m22.3s' '+01d02m03.4s' or '00:11:22.3' '+01:02:03.4' are good"
  echo "  formats for 'ra' and 'dec'."
  echo ""
}

[[ $# -lt 2 ]] && { usage; exit; }

ra="$1"
dec="$2"

_min2sec() {
  local min="$1"
  local sec=$(echo $min | awk '{printf "%d",60*$1}')
  echo "$sec"
}

_hour2sec() {
  local hour="$1"
  local sec=$(echo $hour | awk '{printf "%d",3600*$1}')
  echo "$sec"
}

_convra() {
  local ra="$1"
  local h=$(echo $ra | cut -d':' -f1)
  local m=$(echo $ra | cut -d':' -f2)
  local s=$(echo $ra | cut -d':' -f3)
  h=$(_hour2sec $h)
  m=$(_min2sec $m)
  s=$(echo "$h $m $s" | awk '{print $1+$2+$3}')
  local d=$(echo "$s 360 86400" | awk '{d=$1*$2/$3; printf "%.5f",d}')
  echo "$d"
}

_convdec() {
  local dec="$1"
  local d=$(echo $dec | cut -d':' -f1)
  local m=$(echo $dec | cut -d':' -f2)
  local s=$(echo $dec | cut -d':' -f3)
  m=$(_min2sec $m)
  s=$(echo "$m $s" | awk '{print $1+$2}')
  local pm=$([[ ${d} =~ ^[0-9] ]] && echo '+1' || echo "${d:0:1}1")
  local d=$(echo "$s 3600 $d $pm" | awk '{d=($4*$1/$2)+$3; printf "%.5f",d}')
  echo "$d"
}

_normalize() {
  local coord="$1"
  local _ms=($(echo $coord | tr '[dhm]' ' ' | tr -d 's'))
  local m=0
  local s=0
  local dh=${_ms[0]}
  [[ ${#_ms[@]} -gt 1 ]] && m=${_ms[1]}
  [[ ${#_ms[@]} -gt 2 ]] && s=${_ms[2]}
  echo "${dh}:${m}:${s}"
}

ra=$(_normalize "$ra")
ra=$(_convra "$ra" )

dec=$(_normalize "$dec")
dec=$(_convdec "$dec" )

echo "$ra $dec"
