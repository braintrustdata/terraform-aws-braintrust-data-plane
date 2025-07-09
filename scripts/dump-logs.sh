#!/bin/bash

# Usage:
#   ./dump_logs.sh <deployment_name> [--minutes N] [--service <svc1,svc2,...|all>]

ALL_SERVICES=("brainstore" "AIProxy" "APIHandler" "CatchupETL" "MigrateDatabaseFunction" "QuarantineWarmupFunction" "BillingCron")
SERVICES="APIHandler,brainstore"

if [ -z "$1" ]; then
  echo "Usage: $0 <deployment_name> [--minutes N] [--service <svc1,svc2,...|all>]"
  echo "  deployment_name"
  echo "    The value you used for deployment_name in your terraform module"
  echo "  --minutes N"
  echo "    The number of minutes to fetch logs for (default: 60)"
  echo "  --service <svc1,svc2,...|all>"
  echo "    The services to fetch logs for (default: $SERVICES)"
  echo "    Valid services are: "
  for svc in "${ALL_SERVICES[@]}"; do
    echo "      $svc"
  done
  exit 1
fi

DEPLOYMENT_NAME="$1"
shift
MINUTES=60


while [[ $# -gt 0 ]]; do
  case $1 in
    --minutes)
      MINUTES="$2"
      shift 2
      ;;
    --service)
      SERVICES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ "$SERVICES" == "all" ]]; then
  SELECTED_SERVICES=("${ALL_SERVICES[@]}")
else
  IFS=',' read -ra SELECTED_SERVICES <<< "$SERVICES"
fi

# Timestamps
NOW=$(date -u +%s)
START=$((NOW - MINUTES * 60))

mkdir -p "logs-$DEPLOYMENT_NAME"

for svc in "${SELECTED_SERVICES[@]}"; do
  if [[ "$svc" == "brainstore" ]]; then
    LOG_GROUP="/braintrust/$DEPLOYMENT_NAME/brainstore"
    LOG_FILE="logs-$DEPLOYMENT_NAME/brainstore.log"
  else
    LOG_GROUP="/braintrust/$DEPLOYMENT_NAME/${DEPLOYMENT_NAME}-$svc"
    LOG_FILE="logs-$DEPLOYMENT_NAME/$svc.log"
  fi

  echo "Fetching logs for the last $MINUTES minutes for $svc..."
  (
    if aws logs filter-log-events \
      --log-group-name "$LOG_GROUP" \
      --start-time $((START * 1000)) \
      --end-time $((NOW * 1000)) \
      --query 'events[*].{timestamp:timestamp, message:message}' \
      --output text > "$LOG_FILE"; then
      echo "✅ Saved logs for $svc to $LOG_FILE"
    else
      echo "❌ Failed to fetch logs for $svc"
      rm -f "$LOG_FILE"
    fi
  ) &
done

wait

