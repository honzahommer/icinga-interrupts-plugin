#!/usr/bin/env bash

WARNING="75%"
CRITICAL="90%"

SYSCTL="/sbin/sysctl"

NCPU="$($SYSCTL -in hw.ncpu)"
NQUE="$((NCPU-1))"

help() {
  echo "Usage: $0 -i iface [ -w interrupts ] [ -c interrupts ] [ -h ]"
  echo ""
  echo "  -i iface       : iface to check (eg. igb.0)"
  echo "  -w interrupts  : warning threshold (eg. 24000 or 75%)"
  echo "  -c interrupts  : critical threshold (eg. 28800 or 90%)"
  echo "  -h"
  echo ""
}

while getopts :hi:w:c: option; do
  case "${option}" in
    i) IFACE=${OPTARG};;
    w) WARNING=$OPTARG;;
    c) CRITICAL=$OPTARG;;
    h | *) help
    exit 3;;
  esac
done

if ! echo "$IFACE" | grep -Eq '^i(gb|x).[0-9]+$'; then
  help
  exit 3
fi

MAX_INTERRUPT_RATE="$($SYSCTL -in "hw.$(echo "$IFACE" | grep -Eio '^[a-z]+').max_interrupt_rate")"

if [ -z "$MAX_INTERRUPT_RATE" ]; then
  echo "UNKNOWN - IFACE is not supported"
  exit 3
fi

if echo "$WARNING" | grep -q %\$; then
  WARNING="$(echo "$WARNING" | grep -Eo '^[0-9]+')"
  WARNING="$((MAX_INTERRUPT_RATE*WARNING/100))"
fi

if echo "$CRITICAL" | grep -q %\$; then
  CRITICAL="$(echo "$CRITICAL" | grep -Eo '^[0-9]+')"
  CRITICAL="$((MAX_INTERRUPT_RATE*CRITICAL/100))"
fi

if [ $WARNING -ge $CRITICAL ]; then
  echo "UNKNOWN - WARNING ($WARNING) threshold cannot be bigger than CRITICAL ($CRITICAL)"
  exit 3
fi

INTERRUPTS="$(for ((q=0; q<NQUE; q++)); do
  seq 100 | xargs -I{} sysctl -in "dev.$IFACE.queue$q.interrupt_rate" | sort -n | head -1
done | awk '{ s += $1 } END { print s }')"

if [ -z "$INTERRUPTS" ]; then
  echo "UNKNOWN - Unable to get IFACE interrupts"
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
