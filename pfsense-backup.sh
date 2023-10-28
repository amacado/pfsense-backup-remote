#!/bin/bash
source "/run/scripts/borgBackup.sh"
source "/run/scripts/functions.sh"
##############################################################################################################################
# Main Execution
##############################################################################################################################
sepurator
echo "Starting Docker Container..."
sepurator

# check for required parameters
check_pfSense_vars_set

# borg backups vars set
check_borg_backup_vars

# check for optional parameters
check_pfSense_optional_vars

# set up variables
url=${PFSENSE_SCHEME}://${PFSENSE_IP}:${PFSENSE_PORT}
timestamp=$(date +%Y-%m-%d-%H-%M-%S)
backupFilepath=${destination}/${timestamp}-${BACKUPNAME}.xml

print_container_info

if [ $cron -eq 1 ]; then
  if [ -z "$FROM_CRON" ]; then
    load_crontab_when_exists_or_create
  else
    export BORG_BACKUP_TRUE=""
    sepurator
    run_backups
    cleanup_old_backups_when_set
  fi
else
  sepurator
  run_backups
fi
