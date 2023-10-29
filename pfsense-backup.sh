#!/bin/bash
source "/run/scripts/functions.sh"
##############################################################################################################################
# Main Execution
##############################################################################################################################
separator
echo "Starting Docker Container..."
separator

# check for required parameters
check_pfSense_vars_set

# check for optional parameters
check_pfSense_optional_vars

# set up variables
url=${PFSENSE_SCHEME}://${PFSENSE_IP}:${PFSENSE_PORT}
timestamp=$(date +%Y-%m-%d-%H-%M-%S)
backupFilepath=${destination}/${timestamp}-${BACKUP_NAME}.xml

print_container_info

if [ $cron -eq 1 ]; then
  if [ -z "$FROM_CRON" ]; then
    load_crontab_when_exists_or_create
  fi
fi

separator
run_backups

