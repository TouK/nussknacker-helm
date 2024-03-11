Helm Chart for Nussknacker
==========================

This [Helm](https://github.com/kubernetes/helm) chart installs [Nussknacker](https://nussknacker.io/)
in a Kubernetes cluster. This chart makes an opinionated choice of additional components installed with Nussknacker, but
it is highly configurable.

Quickstart
----------
Check [Quickstart guide](https://nussknacker.io/documentation/quickstart/lite-streaming/) relevant to your [engine](https://nussknacker.io/documentation/about/engines/) and [processing mode](https://nussknacker.io/documentation/about/ProcessingModes/) to see the whole process of installation, configuration of messages schemas and defining of scenarios. You can also check `k8s-helm` directory in [nussknacker-quickstart repository](https://github.com/TouK/nussknacker-quickstart) for an example of K8s based installation. Finally, the `examples` folder of the [Helm chart repo](https://github.com/TouK/nussknacker-helm.git) contains examples how to apply configurations typical to Nussknacker K8s deployment. 

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

The `mode` configuration variable is a convenient umbrella term for the processing mode and engine. See [Glossary](https://nussknacker.io/documentation/about/GLOSSARY) for the explanation of these terms.

By default, the chart runs Nussknacker in `flink` mode which deploys scenarios to Flink engine (either installed directly by the chart, or external one). It is also possible to run Nussknacker on K8s in `lite-k8s` mode. You will need to manually adjust values of the following variables if you use this `mode`:
    ```
    nussknacker:
       mode: lite-k8s
     flink:
       enable: false
     telegraf:
       enabled: false  
    ```

In case if you want to  use only request-response processing mode in your scenarios you can also disable streaming part of the application stack:
    ```
    nussknacker:
       mode: lite-k8s
       streaming:
         enabled: false
     flink:
       enable: false
     telegraf:
       enabled: false  
     kafka:
       enabled: false
     zookeeper:
       enabled: false
     apicurio-registry:
       enabled: false
    ```

Configuration
-------------

Nussknacker configuration is taken from following places:

- [defaultDesignerConfig.conf](https://github.com/TouK/nussknacker/blob/staging/designer/server/src/main/resources/defaultDesignerConfig.conf)  - defaults for Designer,
- [defaultModelConfig.conf](https://github.com/TouK/nussknacker/blob/staging/defaultModel/src/main/resources/defaultModelConfig.conf)    - defaults for default model,
- ```application.conf``` for additional configuration of both model and Designer. In this helm chart ```application.conf``` is defined with ConfigMap (see ```templates/configmap.yaml```). You can provide your own ```application.conf``` by means of `configFile` variable. 

&nbsp;
### Configuration in configmap.yaml

We try to keep this ConfigMap as simple as possible, leaving most of the configuration for ```values.yaml```. In this
ConfigMap, we set a scenario type, usage of a single cluster, some other configuration values. Also,
configurations that depend on other values/templates (like Kafka config, metrics settings) are here, as it is not
possible to e.g. include complex templates easily in values.

&nbsp;
### Configuration in values.yaml

Nussknacker configuration consists of three [configuration areas](https://nussknacker.io/documentation/docs/next/installation_configuration_guide/#configuration-areas); this is reflected in the way the Helm chart variables are defined. 

- `modelConfig` - you can configure the model here (e.g. override Kafka address and so on). Values from this part are
  included in ```modelConfig``` section of the configuration
- `uiConfig` - modifies the Designer configuration options. You can override things like environment name, metrics and so on. They are included on the root level of ```application.conf```
- the Deployment Manager configuration parameters (and Helm variables) are documented fully in Nussknacker configuration [documentation](https://nussknacker.io/documentation/docs/next/installation_configuration_guide/DeploymentManagerConfiguration#lite-engine-based-on-kubernetes); below we mention just those which are most often modified:
  - `k8sDeploymentConfig` - here you can specify your own k8s runtime deployment yaml config in `lite-k8s` mode
  - `requestResponse` - here you can specify `servicePort` and `ingress` configuration for deployed scenarios on k8s when running in `lite-k8s` mode

Yaml keys expected by Nussknacker to be in the form of nested yaml structures in the Values file are converted to json; check the chart implementation if in doubt.  

Please note that not all configurations are one-to-one mapped to Values key names and that in few cases Values key names are different from configuration keys names.

Finally, if you use external (not generated through this chart) Flink instance, use `flinkConfig` to configure it. Check `values.yaml` for available options. These settings are included in ```engineConfig``` section   of ```application.conf ```.

&nbsp;
### Overriding via environment variables

You can override Nussknacker config with env variables, they can be passed in ```values.yaml```
as ```extraEnv```. Please
see [TypesafeConfig](https://github.com/lightbend/config#optional-system-or-env-variable-overrides)
documentation (```CONFIG_FORCE_``` section) to learn how to map env variables to config keys.

&nbsp;
Using your own components/image
---------------------
By default, this chart is installed with the official Nussknacker image, which contains generic components:

- integration with Kafka and Confluent Schema Registry
- base aggregations (accessible only in flink mode)

Should you need to run Nussknacker with your own components/customizations, the best way is to create an image based on the official one and
install the chart with appropriate image configuration. Please note that when using Lite engine you also have to create image of Lite runtime with 
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
  streaming:
    modelClassPath: &streamingModelClassPath
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
            modelClassPath: *streamingModelClassPath
```
Again, for `flink` mode it's only necessary to set `streamingModelClassPath`.

Security/RBAC
-------------
For the Flink engine, Nussknacker doesn't have any special requirements, except for settings specific for dependencies. 

For the Lite engine, Nussknacker Designer manages deployments and configMaps for each scenario. 
Default service account, role and rolebinding will be created, if you want to use existing role, you can specify it with
`rbac.useExistingRole`, you can also skip role and binding creation with `rbac.create` set to `false`.

You can check permissions needed by Nussknacker Designer to run the Lite engine [here](https://github.com/TouK/nussknacker-helm/blob/main/src/templates/role.yml). The set of permissions is quite broad, but they are needed to handle whole lifecycle of a scenario deployment. Because of this, we advise to run Nussknacker in separate Kubernetes namespace.


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

In the `flink` mode, the metrics from Nussknacker are exposed via Prometheus interface. They are read (and preprocessed)
with Telegraf and sent to InfluxDB. When using the Lite engine, the metrics are sent directly from pods running scenarios to InfluxDB.
Grafana with a predefined dashboard is used to visualize process data in Nussknacker.

It is of course possible to replace built-in components with your own. Please look at:

  names are translated, we add additional tags, etc.)
- ```grafana/dashboard.json``` to see the built-in dashboard
- ```countsSettings``` and ```metricsSettings``` in Nussknacker ConfigMap to see how to configure Grafana/InfluxDB URLs
- ```telegraf-configmap.yaml``` to see preprocessing which is done before sending to Grafana (e.g. some Flink metric

**NOTE** Grafana and InfluxDB are by default installed without authentication. To configure it, please follow respective
charts documentation.

Custom labels and annotations.
------------------------------------------------------------
You can define custom annotations and/or labels for Designer pod: 
```
additionalLabels:
  nussknacker.io/example1: custom-label-1
  nussknacker.io/example2: custom-label-2

additionalAnnotations:
  example1: custom-annotation-1
  example2: custom-annotation-2
```

Init containers for Nussknacker.
------------------------------------------------------------
If you need to do any kind of custom setup (e.g. downloading custom components libraries) before running Nussknacker you can use [initContainers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) for that. Example:
```
nussknackerInitContainers:
  - name: prepare-components-extra-libs
    image: some-docker-image:1.0
    command: ['sh', '-c', "cp /extras/* /opt/nussknacker/components/common/extra/"]
    volumeMounts:
    - mountPath: /opt/nussknacker/components/common/extra
      name: components-extras
```


More complex configurations - multiple models, clusters, etc.
------------------------------------------------------------
The chart is highly configurable, but it assumes that there is only one [Model](https://docs.nussknacker.io/documentation/about/GLOSSARY#model), connected with one Flink cluster. If you
want to have different models or have process categories connected to many Flink clusters it's probably easier to create
own chart/deployment with custom Nussknacker configuration (```application.conf``` in ```configmap.yaml```). 

Some configuration properties are not exposed via chart values, so sometimes this steps might be obligatory.

You can deploy configMap/secret on your own using, or use special `extraDeploy` functionality from this chart, which deploys any K8 resource. 
Example:
```
nussknacker:
  mode: "lite-k8s"
  configFile: /etc/nussknacker/application.conf,/etc/nussknacker/extra/extra-application.conf

additionalVolumes:
  - name: extra-config
    configMap:
      name: nu-external-config

additionalVolumeMounts:
  - name: extra-config
    mountPath: /etc/nussknacker/extra

extraDeploy:
- apiVersion: v1
  kind: ConfigMap
  metadata:
    name: nu-external-config
  data:
    extra-application.conf: |-
      environmentAlert {
        content: "example"
        color: "indicator-blue"
      }
```
Mind, that `nusskancker.configFile` accepts multiple configuration files. Here we pass two, one that is generated by this helmchart 
and the second one, which is mounted from configMap.