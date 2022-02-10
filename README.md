# Nussknacker Helm Chart

## Local development

### Prerequisites
- k8s cluster
- helm 3.7+
- pv provider (optional)

### Setup 
Adds necessary repositories and prepares dependencies
```
./setup.sh
```

### Local setup/development
If you don't have K8s available, we recommend installing [k3d](https://k3d.io/).
When you create your cluster with ingress port mapped to 8081 (see [guide](https://k3d.io/v5.0.0/usage/exposing_services/#1-via-ingress-recommended) for details),
Nussknacker designer will be available at `localhost:8081` after executing the steps below.

Use `./build-deploy-verify.sh` script, which upgrades and verifies release. 
It sets `ingress.skipHost=true`, so it's suitable for local K8s like k3d, minikube without decent domain support. 
By default the script uses `deploy-values.yaml`, you can add
other files appending `-f [path]` as many times as needed. Samples:
- `./build-deploy-verify.sh release-name` - deploy chart in flink mode
- `./build-deploy-verify.sh release-name -f deploy-values-lite-yaml` - deploy chart in streaming-lite mode
- `./build-deploy-verify.sh release-name -f deploy-values-lite-yaml -f customComponents/custom-component-docker-values.yaml` - deploy chart in streaming-lite mode, with custom image (see description in `custom-component-docker-values.yaml`)
- `./build-deploy-verify.sh release-name -f deploy-values-lite-yaml -f customComponents/custom-component-url-values.yaml` - deploy chart in streaming-lite mode, with custom component URL (see description in `custom-component-url-values.yaml`)
