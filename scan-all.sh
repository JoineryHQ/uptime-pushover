#!/bin/bash

LOCK=/tmp/uptime-pushover-scan-all.lock
exec 9>"$LOCK" || exit 1
flock -n 9 || exit 0

# Full system path to the directory containing this file, with trailing slash.
# This line determines the location of the script even when called from a bash
# prompt in another directory (in which case `pwd` will point to that directory
# instead of the one containing this script).  See http://stackoverflow.com/a/246128
MYDIR="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )/"

# Source data file or exit.
if [[ ! -e $MYDIR/sites.txt ]]; then
  >&2 echo "Could not find required data file at $MYDIR/sites.txt Exiting."
  exit 1;
fi

# Source config file or exit.
if [ -e $MYDIR/config.sh ]; then
  source $MYDIR/config.sh
else
  >&2 echo "Could not find required config file at $MYDIR/config.sh. Exiting."
  exit 1;
fi

function alert() {
  $MYDIR/send-pushover.sh "$1" "$2";
}

function scanSite() {
  local HEALTH_DOMAIN_NAME=$1;
  local URL="https://${HEALTH_DOMAIN_NAME}/${HEALTH_URL_PATH}"

  local TS="$(date +%Y-%m-%d_%H.%M.%S.%N)"
  local LOGFILE="$LOGDIR/${HEALTH_DOMAIN_NAME}-${TS}.log"

  local TMP_BODY="$(mktemp)"
  local TMP_ERR="$(mktemp)"

  local HTTP_META="$(
    curl -sSL \
      --connect-timeout 3 \
      --max-time 20 \
      --retry 3 \
      --retry-delay 2 \
      -w 'http=%{http_code} total=%{time_total} connect=%{time_connect} tls=%{time_appconnect}' \
      -o "$TMP_BODY" \
      "$URL" 2>"$TMP_ERR"
  )"
  local CURL_EXIT_STATUS=$?

  local BODY="$(<"$TMP_BODY")"
  local ERR="$(<"$TMP_ERR")"

  rm -f "$TMP_BODY" "$TMP_ERR"


  local STATUS_DESC;
  if [[ $CURL_EXIT_STATUS -ne 0 ]]; then
    STATUS_DESC="unreachable"
  elif [[ "$BODY" != "$HEALTH_URL_EXPECTED_STRING" ]]; then
    STATUS_DESC="bad response"
  fi
  if [[ -n "$STATUS_DESC" ]]; then
    # We'll alert; therefore we'll log.
    {
      echo "timestamp: ${TS}"
      echo "site: $HEALTH_DOMAIN_NAME"
      echo "url: $URL"
      echo "curl_exit_status: $CURL_EXIT_STATUS"
      echo "${HTTP_META:-http=(none)}"
      echo "----- stderr -----"
      [[ -n "$ERR" ]] && echo "$ERR" || echo "(none)"
      echo "----- body -----"
      [[ -n "$BODY" ]] && echo "$BODY" || echo "(none)"
    } >"$LOGFILE"

    # Alert.
    alert $HEALTH_DOMAIN_NAME "https://$HEALTH_DOMAIN_NAME $STATUS_DESC (see $(basename $LOGFILE))"
  fi
}

# Ensure log dir exists.
LOGDIR="$MYDIR/alert-logs"
mkdir -p "$LOGDIR"
# Clean out old log files (> 14*24 hours old)
find "$LOGDIR" -type f -mtime +14 -delete

if [[ -n "$1" ]]; then
  # Specfific site was requested; scan only that.
  scanSite "$1";
else
  # No specific site was requested; scan all sites in sites.txt.
  while IFS= read -r line; do
    # Remove everything after '#' (inline comment)
    line="${line%%#*}"

    # Trim leading and trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"   # leading
    line="${line%"${line##*[![:space:]]}"}"   # trailing

    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Now $line is clean
    scanSite "$line";
  done < $MYDIR/sites.txt
fi
