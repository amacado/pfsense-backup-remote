##############################################################################################################################
# Funktionen
##############################################################################################################################
function sepurator {
  echo "======================================================================================"
}

function check_pfSense_vars_set() {
  local errors=0

  if [ -z "$PFSENSE_IP" ]; then echo "Must provide PFSENSE_IP" ; errors=$(($errors + 1)) ; fi
  if [ -z "$PFSENSE_USER" ]; then echo "Must provide PFSENSE_USER" ; errors=$(($errors + 1)); fi
  if [ -z "$PFSENSE_PASS" ]; then echo "Must provide PFSENSE_PASS" ; errors=$(($errors + 1)); fi
  if [ -z "$PFSENSE_SCHEME" ]; then echo "Must provide PFSENSE_SCHEME" ; errors=$(($errors + 1)); fi
  if [ -z "$BACKUPNAME" ]; then BACKUPNAME=$PFSENSE_IP; fi

  if [ $errors -ne 0 ]; then exit 1; fi
}

function check_pfSense_optional_vars() {
  if [ -z "$PFSENSE_CRON_SCHEDULE" ]; then cron=0 ; else cron=1 ; fi
  if [ -z "$PFSENSE_BACK_UP_RRD_DATA" ]; then
    getrrd=""
  else
    if [ "$PFSENSE_BACK_UP_RRD_DATA" == "0" ] ; then
      getrrd="&donotbackuprrd=yes"
    else
      getrrd=""
    fi
  fi
  if [ -z "$PFSENSE_BACKUP_DESTINATION_DIR" ]; then
    destination="/data"
  else
    destination="$PFSENSE_BACKUP_DESTINATION_DIR"
  fi
}

function check_borg_backup_vars() {
  local errors=0

  if [ ! -z "$BORG_BACKUP_TRUE" ]; then
    if [ -z "$BORG_REPO" ]; then echo "Musst provice BORG_REPO"; errors=$(($errors + 1)); fi
    if [ -z "$BORG_CREATE_PARAMS" ]; then echo "Musst provice BORG_CREATE_PARAMS"; errors=$(($errors + 1)); fi
    if [ -z "$BORG_PRUNE_PARAMS" ]; then echo "Musst provice BORG_PRUNE_PARAMS"; errors=$(($errors + 1)); fi
  fi

  if [ $errors -ne 0 ]; then exit 1; fi
}

function load_crontab_when_exists_or_create() {
  if [ -f "$destination/crontab.txt" ]; then
    echo "* Load Crontab $destination/crontab.txt"
    crontab "$destination/crontab.txt"
  else
    echo "* Create $destination/crontab.txt"
    echo "$PFSENSE_CRON_SCHEDULE FROM_CRON=1 /run/pfsense-backup.sh" >> "$destination/crontab.txt"
    crontab "$destination/crontab.txt"
  fi
  sepurator
  crond -f
}

function do_backup() {
  # based on https://docs.netgate.com/pfsense/en/latest/backup/remote-backup.html
  # for using the web ui to initiate and download
  # a xml backup file

  rm -rf ${destination}/tmp
  mkdir ${destination}/tmp

  echo "  * fetch the login form and save the cookies and CSRF token"
  curl -s -L -k --cookie-jar ${destination}/tmp/cookies.txt \
       ${url} \
       | grep "name='__csrf_magic'" \
       | sed 's/.*value="\(.*\)".*/\1/' > ${destination}/tmp/csrf.txt

  echo "  * submit the login form to complete the login procedure"
  curl -s -L -k --cookie ${destination}/tmp/cookies.txt --cookie-jar ${destination}/tmp/cookies.txt \
       --data-urlencode "login=Sign In" \
       --data-urlencode "usernamefld=${PFSENSE_USER}" \
       --data-urlencode "passwordfld=${PFSENSE_PASS}" \
       --data-urlencode "__csrf_magic=$(cat ${destination}/tmp/csrf.txt)" \
       ${url} > ${destination}/tmp/login.html # /dev/null

  echo "  * fetch the target page to obtain a new CSRF token"
  curl -s -L -k --cookie ${destination}/tmp/cookies.txt --cookie-jar ${destination}/tmp/cookies.txt \
       ${url}/diag_backup.php  \
       | grep "name='__csrf_magic'"   \
       | sed 's/.*value="\(.*\)".*/\1/' > ${destination}/tmp/csrf_backup.txt

  echo "  * download the backup to ${backupFilepath}"
  curl -s -L -k --cookie ${destination}/tmp/cookies.txt --cookie-jar ${destination}/tmp/cookies.txt \
       --data-urlencode "backuparea=" \
       --data-urlencode "backupssh=" \
       --data-urlencode "encrypt_password=" \
       --data-urlencode "encrypt_password_confirm=" \
       --data-urlencode "download=download" \
       --data-urlencode "${getrrd}" \
       --data-urlencode "__csrf_magic=$(cat ${destination}/tmp/csrf_backup.txt)" \
       ${url}/diag_backup.php > ${backupFilepath}

  echo "  * validating of configuration is an xml file"
  xmllint --noout ${backupFilepath}
  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "    * xml validation failed"
  else
    echo "    * xml validation successful"

    sepurator

    echo "* Initiate local encryption of the backup file"
    echo "  * Importing public GPG key"
    import_gpg
    echo "  * Encrypt backup using ${GPG_NAME}"
    gpg --no-tty --batch --encrypt --recipient ${GPG_NAME} ${backupFilepath}

    sepurator

    echo "* Prepare and upload encrypted backup to cloud storage"
    glcoud_auth
    /var/lib/google-cloud-sdk/bin/gcloud storage cp ${backupFilepath}.gpg gs://prv-backup-p-stg-euwe1-firewall-8e7c/

    sepurator

  fi

  # Cleanup temporary files and unencrypted backup
  rm -rf ${destination}/tmp
  rm -rf ${backupFilepath}
}

function import_gpg() {
  # import the public gpg key for file encryption
  gpg --import /gpg/config/gpg-public.asc

  # trust the imported public key
  # see https://security.stackexchange.com/a/230911
  (echo 5; echo y; echo save) |
    gpg --command-fd 0 --no-tty --no-greeting -q --edit-key "$(
    gpg --list-packets </gpg/config/gpg-public.asc |
    awk '$1=="keyid:"{print$2;exit}')" trust
}

function glcoud_auth() {
  /var/lib/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=/gcloud/config/service-account-credentials.json
}

function run_backups() {
  echo "* Running backups"
  do_backup
  if [ ! -z "$BORG_BACKUP_TRUE" ]; then
    BORG_CREATE_PARAMS=($BORG_CREATE_PARAMS)
    BORG_PRUNE_PARAMS=($BORG_PRUNE_PARAMS)

    create_borg_backup "$BACKUPNAME" "${backupFilepath}"
    purge_borg_backup "$BACKUPNAME"
    compact_borg_backup

    rm "${backupFilepath}"
  fi
  sepurator
}

function cleanup_old_backups_when_set() {
  if [ ! -z $BACKUP_KEEP ]; then
    remove=$(ls -d -1tr $destination/*.xml | tail -n +$BACKUP_KEEP | head -n1)
    if [ ! -z $remove ]; then
      del=$(ls $destination/*.xml | head -n -$BACKUP_KEEP)
      if [ ! -z $del ]; then
        rm -f $del
        echo "Backup removed at $del"
      fi
    fi
  fi
}

function print_container_info {
  sepurator
  echo "* Backup - Name: $BACKUPNAME"
  sepurator
  echo "* pfSense - Url: $url"
  echo "* pfSense - User: $PFSENSE_USER"
  sepurator
}
