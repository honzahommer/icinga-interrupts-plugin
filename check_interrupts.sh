#!/usr/bin/env bash

if ! uname | grep -iqw freebsd; then
  echo "UNKNOWN - Unsupported platform"
  exit 3
fi

WARNING="75%"
CRITICAL="90%"

help() {
  echo "Usage: $0 -i iface [ -m max ] [ -w interrupts ] [ -c interrupts ] [ -h ]"
  echo ""
  echo "  -i iface       : iface to check (eg. igb.0 or igb0), igb and ix supported"
  echo "  -m max         : maximum interrupts (eg. 32000), default from kernel parameters"
  echo "  -w interrupts  : warning threshold (eg. 24000 or 75%), default 75%"
  echo "  -c interrupts  : critical threshold (eg. 28800 or 90%), default 90%"
  echo "  -h"
  echo ""
  exit 3
}

while getopts :hi:m:w:c: option; do
  case "${option}" in
    i) IFACE=$(echo "$OPTARG" | grep -E '^i(gb|x).?[0-9]+$' | tr -d .) ;;
    m) MAX=${OPTARG##*[!0-9]*} ;;
    w) WARNING=${OPTARG} ;;
    c) CRITICAL=${OPTARG} ;;
    h | *) help ;;
  esac
done

if [ -z "$IFACE" ]; then
  echo "UNKNOWN - Please specify IFACE"
  exit 3
elif ! ifconfig "$IFACE" >/dev/null 2>&1; then
  echo "UNKNOWN - No IFACE ($IFACE) found"
  exit 3
fi

if [ -z ${MAX+x} ]; then
  MAX=$(sysctl -in "hw.$(echo "$IFACE" | grep -Eio '^[a-z]+').max_interrupt_rate")
elif [ -z "$MAX" ]; then
  echo "UNKNOWN - MAX ($MAX) is not number"
  exit 3
fi

if echo "$WARNING" | grep -q %\$; then
  WARNING="$(echo "$WARNING" | grep -Eo '^[0-9]+')"
  WARNING="$((MAX*WARNING/100))"
fi

if echo "$CRITICAL" | grep -q %\$; then
  CRITICAL="$(echo "$CRITICAL" | grep -Eo '^[0-9]+')"
  CRITICAL="$((MAX*CRITICAL/100))"
fi

if [ $WARNING -ge $CRITICAL ]; then
  echo "UNKNOWN - WARNING ($WARNING) threshold cannot be bigger than CRITICAL ($CRITICAL)"
  exit 3
fi

INTERRUPTS=$(vmstat -i | awk '$2 ~ /^'$IFACE':que$/ && $3 >= 0 { s += $NF } END { print s }')

if [ -z "$INTERRUPTS" ]; then
  echo "UNKNOWN - Unable to get IFACE ($IFACE) interrupts"
  exit 3
elif [ "$INTERRUPTS" -ge $CRITICAL ]; then
  echo "CRITICAL - $INTERRUPTS interrupts"
  exit 2
elif [ "$INTERRUPTS" -ge $WARNING ]; then
  echo "WARNING - $INTERRUPTS interrupts"
  exit 1
else
  echo "OK - $INTERRUPTS interrupts"
  exit 0
fi
