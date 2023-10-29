#!/bin/bash
source "/run/scripts/functions.sh"

glcoud_auth
/var/lib/google-cloud-sdk/bin/gcloud auth list --filter=status:ACTIVE --format="value(account)" || exit 1

# @todo: add health checks

exit 0
