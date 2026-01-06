#!/usr/bin/env bash

# Full system path to the directory containing this file, with trailing slash.
# This line determines the location of the script even when called from a bash
# prompt in another directory (in which case `pwd` will point to that directory
# instead of the one containing this script).  See http://stackoverflow.com/a/246128
MYDIR="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )/"

# Source config file or exit.
if [ -e $MYDIR/config.sh ]; then
  source $MYDIR/config.sh
else
  >&2 echo "Could not find required config file at $MYDIR/config.sh. Exiting."
  exit 1;
fi

HANDLE="$1"
BODY="$2"

RECEIPT_FILE="$MYDIR/receipts/receipt.${HANDLE}"

function sendMessage() {
  TITLE="Website alert"
  MESSAGE="$BODY"
  PRIORITY=2   # 0=normal, 1=high, 2=emergency

  # --- send notification ---
  JSON=$(curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "title=$TITLE" \
    --form-string "message=$MESSAGE" \
    --form-string "priority=$PRIORITY" \
    --form-string "retry=60" \
    --form-string "expire=10800" \
    https://api.pushover.net/1/messages.json);
  # Get receipt id if possible, or else (error case) just return.
  RECEIPT_ID="$(echo "$JSON" | jq -er '.receipt' 2>/dev/null)" || return
  # Store the receipt-id so we can query it on future runs.
  echo $RECEIPT_ID > $RECEIPT_FILE
}

mkdir -p "$MYDIR/receipts";

# If we know a receipt-id for a message on $HANDLE,
# check the status of that receipt. Un-acknowledged
# messages, or messages acknowledged only recently,
# will not be re-sent.
if [[ -f $RECEIPT_FILE ]]; then
  OLD_RECEIPT_ID=$(cat $RECEIPT_FILE);
  RECEIPT_STATUS_JSON=$(curl -s "https://api.pushover.net/1/receipts/${OLD_RECEIPT_ID}.json?token=${PUSHOVER_TOKEN}")
  ACK=$(echo $RECEIPT_STATUS_JSON | jq -r '.acknowledged')
  if [[ "$ACK" == "1" ]]; then
    ACK_AT=$(echo $RECEIPT_STATUS_JSON | jq -r '.acknowledged_at')
    NOW="$(date +%s)"
    ACK_AGE=$((NOW - ACK_AT))
    # if acknowledged > 5 min ago, delete receipt file.
    if [[ $ACK_AGE -gt $MAX_ACK_AGE ]]; then
      # Delete our record of this message/receipt. Thus a message will
      # be sent on the next alert cycle.
      rm $RECEIPT_FILE;
    fi
  fi
else
  sendMessage;
fi
