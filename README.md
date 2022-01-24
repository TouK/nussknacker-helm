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

Use `./build-deploy-verify.sh` script, which upgrades and verifies release. By default it uses `deploy-values.yaml`, you can add
other files appending `-f [path]` as many times as needed. Samples:
- `./build-deploy-verify.sh release_name` - deploy chart in flink mode
- `./build-deploy-verify.sh release_name -f deploy-values-lite-yaml` - deploy chart in streaming-lite mode
- `./build-deploy-verify.sh release_name -f deploy-values-lite-yaml -f customComponents/custom-component-docker-values.yaml` - deploy chart in streaming-lite mode, with custom image (see description in `custom-component-docker-values.yaml`)
- `./build-deploy-verify.sh release_name -f deploy-values-lite-yaml -f customComponents/custom-component-url-values.yaml` - deploy chart in streaming-lite mode, with custom component URL (see description in `custom-component-url-values.yaml`)
