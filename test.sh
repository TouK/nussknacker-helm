#!/bin/bash

set -e 

RELEASE=$1

function logOnExit {
    echo -e "\n\n\n\n\n"
    kubectl get pod
    echo -e "\n\n\n\n\n"
    kubectl logs job/$RELEASE-nussknacker-test-job test-job || echo "Failed to log job..."
    echo -e "\n\n\n\n\n"
    kubectl describe job/$RELEASE-nussknacker-test-job || echo "Failed to describe job..."
    echo -e "\n\n\n\n\n"
    kubectl logs -l nussknacker.io/scenarioId  || echo "Failed to log scenarios"
    echo -e "\n\n\n\n\n"
    kubectl describe pod -l nussknacker.io/scenarioId
    echo -e "\n\n\n\n\n"
    kubectl logs --tail 1000 -l app.kubernetes.io/name=management
    echo -e "\n\n\n\n\n"
    kubectl logs --tail 1000 -l app.kubernetes.io/name=nussknacker
    echo -e "\n\n\n\n\n"
    kubectl logs --tail 1000 -l app.kubernetes.io/name=apicurio-registry
    echo -e "\n\n\n\n\n"
    kubectl get event -A
}
trap 'logOnExit' EXIT

helm test "$RELEASE" --timeout 10m0s
