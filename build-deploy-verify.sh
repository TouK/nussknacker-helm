#!/bin/sh

# This script is intended for local development only.
# It should copy behaviour of 'deploy' phase in .gitlab-ci.yml
# The RELEASE should in general be the name of branch in gitlab (sanitized by gitlab)
# Before first usage repos should be added (as in build.script phase in .gitlab-ci.yml

RELEASE="${1?usage: $(basename $0) [NAME]}"

cd "$(dirname "$0")" && rm -r dist/

helm package -d dist/ src/
helm upgrade -i "${RELEASE}" dist/*.tgz --set postgresql.existingSecret="${RELEASE}-postgresql" --set telegraf.existingConfigMapName="${RELEASE}-telegraf-configuration" -f deploy-values.yaml

kubectl delete jobs --all
helm test "${RELEASE}"
