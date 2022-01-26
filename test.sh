#!/bin/bash

set -e 

RELEASE=$1

function logOnExit {
    kubectl get pod
    kubectl logs job/$RELEASE-nussknacker-test-job test-job || echo "Failed to log job..."
    kubectl describe job/$RELEASE-nussknacker-test-job || echo "Failed to describe job..."
    kubectl logs job/$RELEASE-hermes-test-job test-job || echo "Failed to log job..."
    kubectl describe job/$RELEASE-hermes-test-job || echo "Failed to describe job..."
    kubectl logs -l nussknacker.io/scenarioId  || echo "Failed to log scenarios"
}
trap 'logOnExit' EXIT

helm test "$RELEASE"