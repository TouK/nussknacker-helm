#!/bin/sh

# This script is intended for local development only.

RELEASE="${1?usage: $(basename $0) [NAME]}"

cd "$(dirname "$0")" && rm -r dist/

helm package -d dist/ src/
helm upgrade -i "${RELEASE}" dist/*.tgz --set postgresql.existingSecret="${RELEASE}-postgresql" -f deploy-values.yaml

kubectl delete jobs --all
helm test "${RELEASE}"
