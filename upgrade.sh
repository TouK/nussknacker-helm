#!/bin/bash

set -e 

RELEASE=$1

function logOnExit {
    kubectl get pod
    kubectl logs --tail 1000 -l app.kubernetes.io/name=management
    kubectl logs --tail 1000 -l app.kubernetes.io/name=nussknacker
}
trap 'logOnExit' EXIT

helm upgrade -i $1 dist/*.tgz --version $2 --wait --debug -f deploy-values.yaml -f $3