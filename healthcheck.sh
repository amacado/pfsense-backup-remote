#!/bin/bash
source "/run/scripts/functions.sh"

glcoud_auth
gcloud auth list --filter=status:ACTIVE --format="value(account)"

# @todo: add health checks
