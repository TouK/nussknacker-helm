#!/bin/sh

helm repo add touk https://helm-charts.touk.pl/public/
helm repo add influxdata https://helm.influxdata.com/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add riskfocus https://riskfocus.github.io/helm-charts-public/
helm dependencies build src