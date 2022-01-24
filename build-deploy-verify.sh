#!/bin/bash

# This script is intended for local development only.
# It should copy behaviour of 'deploy' phase in .gitlab-ci.yml
# The RELEASE should in general be the name of branch in gitlab (sanitized by gitlab)
# Before first usage repos should be added (as in build.script phase in .gitlab-ci.yml

set -e
RELEASE="${1?usage: $(basename $0) [NAME] [ADDITIONAL VALUES]}"
shift 

cd "$(dirname "$0")" && rm -rf dist/
helm package -d dist/ src/
kubectl get secret "$RELEASE-postgresql" || kubectl create secret generic "$RELEASE-postgresql" --from-literal postgresql-password=`date +%s | sha256sum | base64 | head -c 32`
helm upgrade -i "${RELEASE}" dist/*.tgz \
  --wait \
  --set ingress.skipHost=true \
  --set postgresql.existingSecret="${RELEASE}-postgresql" \
  -f deploy-values.yaml $@ 

kubectl delete jobs --all
helm test "${RELEASE}"
