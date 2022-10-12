Helm Chart for Nussknacker
==========================

This [Helm](https://github.com/kubernetes/helm) chart installs [Nussknacker](https://nussknacker.io/)
in a Kubernetes cluster. This chart makes an opinionated choice of additional components installed with Nussknacker, but
it is highly configurable.

Quickstart
----------
To go through the whole process of installation, configuration of messages schemas and defining of scenarios,
see [Quickstart guide](https://nussknacker.io/documentation/quickstart/helm/)
or `k8s-helm` directory in [nussknacker-quickstart repository](https://github.com/TouK/nussknacker-quickstart)

Requirements
------------

- helm 3.7.x
- PV provisioner support in the underlying infrastructure (optional for development/testing purposes)

Installing the Chart 
------------
To install the chart with the release name my-nussknacker:
```
helm repo add touk https://helm-charts.touk.pl/public
helm install my-nussknacker touk/nussknacker --set ingress.skipHost=true
```
Then, you can set up `port-forward`:
```
kubectl port-forward service/my-nussknacker 8080:80
```
and visit Designer app on http://localhost:8080/

Upgrade the Chart
-------
```
kubectl create secret generic nussknacker-postgresql --from-literal postgres-password=`date +%s | sha256sum | base64 | head -c 32`
helm upgrade --set postgresql.auth.existingSecret=nussknacker-postgresql my-nussknacker touk/nussknacker
```

Uninstalling the Chart
----------------------
To uninstall the my-nussknacker release:
```
helm uninstall my-nussknacker
```
The command removes all the Kubernetes components associated with the chart and deletes the release.
To remove all scenario deployments and its data run
```
kubectl delete deployment,service,configmap -l nussknacker.io/nussknackerInstanceName=my-nussknacker
```

Components
----------
By default, the chart is "with batteries included" - it installs all that is needed to work with Nussknacker, including
Flink itself, Kafka, monitoring, etc. Of course, in production deployment, some of those components will probably be
provided outside. The table below lists components and their roles

| Component       | Description                                                               | Enabled by default |
|-----------------|---------------------------------------------------------------------------|--------------------|
| Nussknacker     | Nussknacker UI application                                                | true               |
| PostgreSQL      | Nussknacker database                                                      | true               |
| Kafka           | Main source and sink of events processed by Nussknacker processes         | true               |
| Schema Registry | Registry of AVRO schemas                                                  | true               |
| InfluxDB        | Metrics database                                                          | true               |
| Grafana         | Metrics frontend                                                          | true               |
| Flink           | Runtime for Nussknacker jobs                                              | true               |
| Telegraf        | Relay passing metrics from Flink to InfluxDB                              | true               |

Modes
-----
By default, the chart runs Nussknacker in `streaming` mode which is configured to deploy scenarios on Flink 
(either installed directly by the chart, or external one). 

It is also possible to run Nussknacker in:
* `streaming-lite` mode:
    ```
    nussknacker:
       mode: streaming-lite
     flink:
       enable: false
     telegraf:
       enabled: false  
    ```
    In this mode scenarios will be deployed as K8s deployments. See [Nussknacker documentation](https://docs.nussknacker.io) for the details. 
* `request-response` mode
    ```
    nussknacker:
       mode: request-response
     flink:
       enable: false
     telegraf:
       enabled: false  
    ```
  In this mode scenarios will be also deployed as K8s deployments, but in `request-response` processing mode. See [Nussknacker documentation](https://docs.nussknacker.io) for the details.


Designer configuration
-------------

Nussknacker configuration is taken from following places

- [defaultUiConfig.conf](https://github.com/TouK/nussknacker/blob/staging/ui/server/src/main/resources/defaultUiConfig.conf)
    - defaults for UI
- [defaultModelConfig.conf](https://github.com/TouK/nussknacker/blob/staging/defaultModel/src/main/resources/defaultModelConfig.conf)
    - defaults for default model.
- ```application.conf``` for configuring both model and UI. In this helm chart ```application.conf``` is defined with
  ConfigMap (see ```templates/configmap.yaml```)

**NOTE** Currently it's not possible to use own ```application.conf``` with the chart. In the future you will be able to
use your own ConfigMap for that.

#### Configuration in configmap.yaml

We try to keep this ConfigMap as simple as possible, leaving most of the configuration for ```values.yaml```. In this
ConfigMap, we fix one processType, usage of a single cluster, some other fixed configuration values. Also,
configurations that depend on other values/templates (like Kafka config, metrics settings) are here, as it is not
possible to e.g. include complex templates easily in values.

#### Configuration in values.yaml

There are three major parts of Nussknacker configuration in ```values.yaml```

- `modelConfig` - one can configure the model here (e.g. override Kafka address and so on). Values from this part are
  included in ```modelConfig``` section of the configuration
- `uiConfig` - one can override things like environment name, metrics and so on. They are included on the root level
  of ```application.conf```
- `flinkConfig` - here Flink cluster URL can be overridden. These settings are included in ```engineConfig``` section
  of ```application.conf ```
- `k8sDeploymentConfig` - here you can specify your own k8s runtime deployment yaml config in `streaming-lite` and `request-response` mode
- `requestResponse` - here you can specify `servicePort` and `ingress` configuration for deployed scenarios on k8s when running in `request-response` mode

#### Overriding via environment variables

You can override Nussknacker config with env variables, they can be passed in ```values.yaml```
as ```extraEnv```. Please
see [TypesafeConfig](https://github.com/lightbend/config#optional-system-or-env-variable-overrides)
documentation (```CONFIG_FORCE_``` section) to learn how to map env variables to config keys.


Using your own components/image
---------------------
By default, this chart is installed with the official Nussknacker image, which contains generic components:

- integration with Kafka and Confluent Schema Registry
- base aggregations (accessible only in flink mode)

Should you need to run Nussknacker with your own components/customizations, the best way is to create an image based on the official one and
install the chart with appropriate image configuration. Please note that in streaming-lite mode you also have to create image of lite runtime with 
components (see [nussknacker-sample-components](https://github.com/TouK/nussknacker-sample-components) for the details). Using custom images can
be configured in following way: 
```
nussknacker:
  runtimeImage:
    repository: nussknacker-sample-components-lite-runtime-app
    tag: 1.15
image:
  repository: nussknacker-sample-components
  tag: 1.15
```  
For flink mode, only `image.repository` configuration is needed, as Designer itself prepares fatjar with dependencies of the Flink job.

Other way of installing custom components is direct configuration of classpath, adding URL accessible in the K8s cluster. Below sample 
configuration adding additional JDBC driver for [SQL enrichers](https://docs.nussknacker.io/documentation/docs/scenarios_authoring/Enrichers#sql-enricher):
```
nussknacker:
  #At the moment one has to override whole classPath to add custom entries
  modelClassPath: &modelClassPath
    - "model/defaultModel.jar"
    - "components/lite/liteBase.jar"
    - "components/lite/liteKafka.jar"
    - "components/common"
    - "https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.6.1/hsqldb-2.6.1.jar"
  uiConfig:
    scenarioTypes:
      default:
        deploymentConfig:
          configExecutionOverrides: 
            modelClassPath: *modelClassPath
```
Again, for flink mode it's only necessary to set `modelClassPath`.

Security/RBAC
-------------
For flink mode Nussknacker doesn't have any special requirements, except for settings specific for dependencies. 

For streaming-lite mode, Nussknacker Designer manages deployments and configMaps for each scenario. 
Default service account, role and rolebinding will be created, if you want to use existing role, you can specify it with
`rbac.useExistingRole`

Ingress 
-------
Following configuration is needed to use Ingress (domain has to be TLD). 
```ingress:
  enabled: true
  domain: "example.nussknacker.pl"
```
By default host name will be equal to release name (can be overridden with `nussknacker.ingress.host`) and Nussknacker Designer will be available 
at `http(s)://[host].[domain]`.

If you want to try out this chart on installation without proper domain support (e.g. local minikube/k3d etc.) you can set
```
  ingress:
    enabled: true
    skipHost: true
```
and Designer's ingress will match any host. 

Authentication
--------------
By default, Nussknacker comes with simple BASIC authentication. Other methods
(e.g. OAuth2) can be configured by setting appropriate values

- please follow Nussknacker documentation

Monitoring/metrics
----------
The chart comes with the following monitoring components:

- Influxdb
- Grafana
- Telegraf (used in flink mode)

In the flink mode, the metrics from Nussknacker are exposed via Prometheus interface. They are read (and preprocessed)
with Telegraf and sent to InfluxDB. In the streaming-lite mode, the metrics are sent directly from pods running scenarios to InfluxDB.
Grafana with a predefined dashboard is used to visualize process data in Nussknacker.

It is of course possible to replace built-in components with your own. Please look at:

  names are translated, we add additional tags, etc.)
- ```grafana/dashboard.json``` to see the built-in dashboard
- ```countsSettings``` and ```metricsSettings``` in Nussknacker ConfigMap to see how to configure Grafana/InfluxDB URLs
- ```telegraf-configmap.yaml``` to see preprocessing which is done before sending to Grafana (e.g. some Flink metric

**NOTE** Grafana and InfluxDB are by default installed without authentication. To configure it, please follow respective
charts documentation.


More complex configurations - multiple models, clusters, etc.
------------------------------------------------------------
The chart is highly configurable, but it assumes that there is only one [Model](https://docs.nussknacker.io/documentation/about/GLOSSARY#model), connected with one Flink cluster. If you
want to have different models or have process categories connected to many Flink clusters it's probably easier to create
own chart/deployment with custom Nussknacker configuration (```application.conf``` in ```configmap.yaml```).
