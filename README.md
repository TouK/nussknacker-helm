# Nussknacker Helm Chart

## Local development

### Prerequisites
- k8s cluster
- pv provider
- helm 3.7+


Change directory to src/
```
cd src/
```

Add repositories
```
helm repo add riskfocus https://riskfocus.github.io/helm-charts-public/
helm repo add touk https://helm-charts.touk.pl/public/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add bitnami https://charts.bitnami.com/bitnami/
helm repo add influxdata https://helm.influxdata.com/

```

### Checking dependencies
```
helm dep list
helm dep update
```

### Dry-run
```
helm install nussknacker . --set ingress.enabled=true --set ingress.domain=default.svc.cluster.local --dry-run
```

### Instalation
```
helm install nussknacker . --set ingress.enabled=true --set ingress.domain=default.svc.cluster.local
```
This command may last longer for the first time due to pulling images.

### Upgrade
```
kubectl get secret "nussknacker-postgresql" || kubectl create secret generic nussknacker-postgresql  --from-literal postgresql-password=`date +%s | sha256sum | base64 | head -c 32`
helm upgrade --set postgresql.existingSecret=nussknacker-postgresql nussknacker .
```
