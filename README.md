# amacado/pfsense-backup

## Short description
Runs a lightweight Alpine container to backup PFSense and push the backups to an remote location.

## Full details
This image can be used to run a one-time backup of PFSense, or it can be configured to stay in the background and retrieve backups on a user-specified schedule.
This has been tested to work against PFSense 2.7.0-RELEASE. It might stop working if PFSense changes something about how backups are completed.
By default the backup will contain all the RRD data, if that is not desired see Parameters below.

### Google Cloud credentials
* Visit https://console.cloud.google.com/iam-admin/serviceaccounts?project=<YOUR-PROJECT> and make/download a key for one of the service accounts (or create new one)
* Add required roles 
  * Storage Object Creator (Allows users to create objects. Does not give permission to view, delete, or replace objects.)
  * Storage Object Viewer (Grants access to view objects and their metadata, excluding ACLs. Can also list the objects in a bucket.)
* Create and download an Access Key File (JSON) for the service account
* Use file in mount for `/gcloud/config/service-account-credentials.json`
  * `- "<path-to>/gcloud-xxx-yyyyy.json:/gcloud/config/service-account-credentials.json"`

### GPG encryption
The backup file is encrypted using a GPG key. For setup encryption follow:
* Create a public/private GPG key pair
* Provide the public key to as volume mount for `/gpg/config/gpg-public.asc`
* Make sure you don't lose the private key or you will be unable to decrypt your backups

### Running
#### One-time container
This is a good method for testing to ensure all the parameters are correct. If this command does not succeed, the cron-version below will most likely not succeed either.

Running this command will start the container, connect to the PFSense host specified with the credentials provided and retrieve a backup. The backup file will be placed in the directory the command was run from, the container will then quit.
```
docker run --rm --volume $(pwd):/data --env PFSENSE_USER=backupuser --env PFSENSE_IP=192.168.0.1 --env PFSENSE_PASS=changeme --env PFSENSE_SCHEME=https daniel156161/pfsense-backup
```
#### Continuous container
It's recommended to test the parameters with the one-time version above before trying the continuous backup mode out.

Running this command will start the container and send it to the background. While in the background the container will connect to the PFSense host specified with the credentials provided and retrieve a backup. The backup file will be placed in the directory the command was run from. On the cron schedule, a new backup file will be placed in that directory.

This specific command will back up once per day at midnight UTC, as the container's time zone is set to UTC.
```
docker run --detach --volume $(pwd):/data --env PFSENSE_USER=backupuser --env PFSENSE_IP=192.168.0.1 --env PFSENSE_PASS=changeme --env PFSENSE_SCHEME=https --env PFSENSE_CRON_SCHEDULE='0 0 * * *' daniel156161/pfsense-backup
```

### Parameters
- `PFSENSE_USER` Required. The PFSense user to log in with.
- `PFSENSE_PASS` Required. The password for the PFSense user specified.
- `PFSENSE_IP` Required. The IP (or DNS name) of the PFSense server.
- `BACKUPNAME` Required. Backupname for xml.
- `PFSENSE_SCHEME` Required. Should either be `http` or `https`. This parameter is not validated.
- `PFSENSE_CRON_SCHEDULE` Optional. The cron schedule to use, should contain 5 items separated by spaces. This parameter is not validated. No default.
- `PFSENSE_BACK_UP_RRD_DATA`. Optional. Should be either 1 or 0. This parameters is not validated. Include RRD data in the backup? 1=yes, 0=no. Default=1.
- `PFSENSE_BACKUP_DESTINATION_DIR`. Optional. What is the destination directory to back up to. This directory must exist and be writable. Default=/data
- `TZ`. Optional. Timezone settings
- `keepfiles` . Optional. How many Files do you like to keep

### Crontab
- can run custom crontab commands just put your command into the crontab.txt file

## Help!
- Is the username correct?
- Is the password correct? Is it quoted properly?
- The container runs in the UTC timezone, so the cron schedule might be offset from what was expected when the TZ env is not set

## Credits
forked from [daniel156161/pfsense-backup](https://github.com/daniel156161/pfsense-backup)
