#!/bin/sh

set -e

helm repo add --force-update touk https://helm-charts.touk.pl/public/
helm repo add --force-update influxdata https://helm.influxdata.com/
helm repo add --force-update grafana https://grafana.github.io/helm-charts
helm repo add --force-update bitnami https://charts.bitnami.com/bitnami
helm repo add --force-update riskfocus https://riskfocus.github.io/helm-charts-public/
helm dependencies build src
