# Nussknacker Helm Chart

## Chart
Released chart can be found in [artifacthub](https://artifacthub.io/packages/helm/touk/nussknacker)

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
By default, the script uses `deploy-values.yaml`, you can add
other files appending `-f [path]` as many times as needed. 

Dev samples:
- `./build-deploy-verify.sh release-name` - deploy chart with streaming using flink deployment mode
- `./build-deploy-verify.sh release-name -f deploy-values-lite.yaml` - deploy chart with streaming using lite-k8s deployment mode

Examples:
- `./build-deploy-verify.sh release-name -f deploy-values-lite.yaml -f examples/customComponents/custom-component-docker-values.yaml` - deploy chart with streaming using lite-k8s deployment mode, with custom image (see description in `custom-component-docker-values.yaml`)
- `./build-deploy-verify.sh release-name -f deploy-values-lite.yaml -f examples/customComponents/custom-component-url-values.yaml` - deploy chart with streaming using lite-k8s deployment mode, with custom component URL (see description in `custom-component-url-values.yaml`)
- `./build-deploy-verify.sh release-name -f deploy-values-lite.yaml -f examples/customSecret/custom-secret-values.yaml` - deploy chart with streaming using lite-k8s deployment mode, passing secret to both designer and runtime container (see description in `custom-secret-values.yaml`)
- `./build-deploy-verify.sh release-name -f deploy-values-lite.yaml -f examples/custom-logging.yaml` - deploy chart with streaming using lite-k8s deployment mode with custom logging configuration of the designer and runtime containers (see description in `custom-logging.yaml`) 
- `./build-deploy-verify.sh release-name -f examples/customConfig/custom-conf-values.yaml` - deploy chart with streaming using lite-k8s deployment mode with additional config map with custom application.conf configuration of the designer

### Rendering helm locally
To check how helm is rendered with default values, you can execute helm this way in root directory:
```
helm template -f deploy-values.yaml --set "image.tag=staging-latest" --debug ./src
```