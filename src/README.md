Helm Chart for Nussknacker
==========================

This [Helm](https://github.com/kubernetes/helm) chart installs [Nussknacker](https://nussknacker.io/) 
in a Kubernetes cluster.
This chart makes an opinionated choice of additional components installed with Nussknacker, but it is highly configurable.

Components
----------
By default, the chart is "with batteries included" - it installs all that is needed to work with Nussknacker, including
Flink itself, Kafka, monitoring, etc. Of course, in production deployment, some of those components will probably
be provided outside. The table below lists components and their roles


| Component   | Description       | Enabled by default     |
| ------------| ----------------- | ------------------------------- |
| Nussknacker | Nussknacker UI application                                                  | true    |
| PostgreSQL  | Nussknacker database                                                        | true    |
| Flink       | Runtime for Nussknacker jobs                                                | true    |
| Kafka       | Main source and sink of events processed by Nussknacker processes           | true    |
| Schema Registry | Registry of AVRO schemas                                                | true    |
| Telegraf    | Relay passing metrics from Flink to InfluxDB                                | true    |
| InfluxDB    | Metrics database                                                            | true    |
| Grafana     | Metrics frontend                                                            | true    |
| Hermes      | Additional component enabling sending/receiving Kafka events via REST API   | false   |

Configuration
-------------

Nussknacker configuration is taken from following places
- [defaultUiConfig.conf](https://github.com/TouK/nussknacker/blob/staging/ui/server/src/main/resources/defaultUiConfig.conf) - defaults for UI
- [defaultModelConfig.conf](https://github.com/TouK/nussknacker/blob/staging/engine/flink/generic/src/main/resources/defaultModelConfig.conf) - defaults for each model
- ```application.conf``` for configuring both model and UI.
In this helm chart ```application.conf```is defined with ConfigMap (see ```templates/configmap.yaml```) 

**NOTE** Currently it's not possible to use own ```application.conf``` with the chart. In the 
future you will be able to use your own ConfigMap for that. 

#### Configuration in configmap.yaml
We try to keep this ConfigMap as simple as possible, leaving most of the configuration for ```values.yaml```.
In this ConfigMap, we fix one processType, usage of a single cluster, some other fixed configuration values.
Also, configurations that depend on other values/templates (like Kafka config, metrics settings) are
here, as it is not possible to e.g. include complex templates easily in values.

#### Configuration in values.yaml
There are three major parts of Nussknacker configuration in ```values.yaml```
- modelConfig - one can configure the model here (e.g. override Kafka address and so on). Values from this part are included in ```modelConfig``` section of the configuration 
- uiConfig - one can override things like environment name, metrics and so on. They are included on the root level of ```application.conf```
- flinkConfig - here Flink cluster URL can be overridden. These settings are included in ```engineConfig``` section of ```application.conf 


#### Overriding via environment variables
You can override Nussknacker config with env variables, they can be passed in ```values.yaml``` 
as ```extraEnv```. Please see [TypesafeConfig](https://github.com/lightbend/config#optional-system-or-env-variable-overrides)
documentation (```CONFIG_FORCE_``` section) to learn how to map env variables to config keys.


Using your own model/image
---------------------
By default, this chart is installed with the official Nussknacker image, which contains
generic data model: 
- integration with Kafka and Confluent Schema Registry
- base aggregations

Should you need to run Nussknacker with your own model, the best way is to create an
image based on the official one and install the chart with appropriate image configuration.

Authentication
--------------
By default, Nussknacker comes with simple BASIC authentication. Other methods
(e.g. OAuth2) can be configured by setting appropriate values 
- please follow Nussknacker documentation


Monitoring/metrics
----------
The chart comes with the following monitoring components:
- Telegraf
- Influxdb
- Grafana

Metrics from Nussknacker are exposed in Flink via Prometheus. They are read (and preprocessed)
with Telegraf and sent to InfluxDB. Grafana with a predefined dashboard is used to visualize process data in Nussknacker.

It is of course possible to replace built-in components with your own. Please look at:
- ```telegraf-configmap.yaml``` to see preprocessing which is done before sending to Grafana (e.g. some Flink metric
names are translated, we add additional tags, etc.)
- ```grafana/dashboard.json``` to see the built-in dashboard
- ```countsSettings``` and ```metricsSettings``` in Nussknacker ConfigMap to see how to configure Grafana/InfluxDB URLs

**NOTE** Grafana and InfluxDB are by default installed without authentication. To configure it, please
follow respective charts documentation.


More complex configurations - multiple models, clusters, etc. 
------------------------------------------------------------
The chart is highly configurable, but it assumes that there is only one model, connected with one Flink cluster. 
If you want to have different models or have process categories connected to many Flink clusters it's probably
easier to create own chart/deployment with custom Nussknacker configuration (```application.conf``` in ```configmap.yaml```)
