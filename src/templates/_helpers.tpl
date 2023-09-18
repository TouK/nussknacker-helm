{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "nussknacker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "nussknacker.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}



{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nussknacker.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nussknacker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "nussknacker.labels" -}}
helm.sh/chart: {{ include "nussknacker.chart" . }}
{{ include "nussknacker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "nussknacker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nussknacker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "nussknacker.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "nussknacker.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.kafkaBootstrapServers" -}}
{{- if .Values.kafka.enabled }}
{{- include "common.names.fullname" .Subcharts.kafka }}:{{- .Values.kafka.service.ports.client }}
{{- else -}}
{{- required "Enable Kafka or provide global values for bootstrap servers." (include "nussknacker.globalKafkaBootstrapServers" . | trim) }}
{{- end }}
{{- end }}

{{- define "nussknacker.globalKafkaBootstrapServers" -}}
{{- if .Values.global.kafka.bootstrapServers }}
{{- tpl (join "," .Values.global.kafka.bootstrapServers) . }}
{{- else }}
{{- if .Values.global.kafka.fullname }}
{{- .Values.global.kafka.fullname | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- if .Values.global.kafka.name }}
{{- $name := .Values.global.kafka.name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.global.kafka.port }}
{{- printf ":%v" .Values.global.kafka.port }}
{{- end }}
{{- end }}
{{- end }}

{{- define "nussknacker.schemaRegistryUrl" -}}
{{- if index .Values "apicurio-registry" "enabled" -}}
http://{{ include "apicurio-registry.fullname" ( index .Subcharts "apicurio-registry" ) }}:{{ index .Values "apicurio-registry" "service" "port" }}/apis/ccompat/v6/
{{- else -}}
{{- required "Enable apicurio-registry or provide global values for a scheme registry url." (include "nussknacker.globalSchemaRegistryUrl" . | trim) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.globalSchemaRegistryUrl" -}}
{{- if .Values.global.schemaRegistry.url }}
{{- .Values.global.schemaRegistry.url }}
{{- else }}
{{- if .Values.global.schemaRegistry.fullname }}
{{- .Values.global.schemaRegistry.fullname | trunc 63 | trimSuffix "-" | printf "http://%s" }}
{{- else }}
{{- if .Values.global.schemaRegistry.name }}
{{- $name := .Values.global.schemaRegistry.name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" | printf "http://%s" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" | printf "http://%s" }}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.global.schemaRegistry.port }}
{{- printf ":%d" .Values.global.schemaRegistry.port }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "nussknacker.flinkJobManagerUrl" -}}
{{- if .Values.flink.enabled -}}
    http://{{ include "flink.fullname" (dict "Chart" (dict "Name" "flink") "Values" .Values.flink "Release" .Release "Capabilities" .Capabilities) }}-jobmanager-rest:8081
{{- else -}}
    {{ required "Enable flink or provide a valid .Values.nussknacker.job-manager-url entry!" ( tpl ( index .Values "nussknacker" "job-manager-url" ) . ) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.flinkTaskManagerUrl" -}}
{{- if .Values.flink.enabled -}}
    {{ include "flink.fullname" (dict "Chart" (dict "Name" "flink") "Values" .Values.flink "Release" .Release "Capabilities" .Capabilities) }}-taskmanager:6122
{{- else -}}
    {{ required "Enable flink or provide a valid .Values.nussknacker.task-manager-url entry!" ( tpl ( index .Values "nussknacker" "task-manager-url" ) . ) }}
{{- end -}}
{{- end -}}


{{- define "nussknacker.fqdn" -}}
    {{- $domain := required "Provide a domain name" .Values.ingress.domain -}}
    {{- $fullName := default (include "nussknacker.fullname" .) .Values.ingress.host -}}
    {{- printf "%s.%s" $fullName $domain -}}
{{- end -}}

{{/* TODO: configurable path, proper ingress configuration   */}}
{{- define "nussknacker.grafanaUrl" -}}
    {{- if not .Values.ingress.skipHost -}}
    https://{{- include "nussknacker.fqdn" . -}}
    {{- end -}}/grafana
{{- end -}}

{{/* TODO: handling custom port */}}
{{- define "nussknacker.influxUrl" -}}
    http://{{ include "influxdb.fullname" (dict "Chart" (dict "Name" "influxdb") "Values" .Values.influxdb "Release" .Release "Capabilities" .Capabilities) }}:8086
{{- end -}}

{{- define "nussknacker.defaultDashboard" -}}
{{- if eq .Values.nussknacker.mode "flink" -}}
nussknacker-scenario
{{- else if eq .Values.nussknacker.mode "streaming-lite" -}}
nussknacker-lite-scenario
{{- else if eq .Values.nussknacker.mode "request-response" -}}
nussknacker-request-response-scenario
{{- else -}}
{{- .Values.nussknacker.defaultDashboard }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.modelClassPath" -}}
{{- if .Values.nussknacker.modelClassPath -}}
{{ tpl ( mustToJson .Valumes.nussknacker.modelClassPath) . }}
{{- else if eq .Values.nussknacker.mode "ververica" -}}
["components/ververica/defaultModel.jar", "components/ververica/flinkBase.jar", "components/ververica/flinkExecutor.jar", "components/ververica/flinkKafka.jar", "managers/ververica/ververica-2.13.jar"]
{{- else if eq .Values.nussknacker.mode "flink" -}}
["model/defaultModel.jar", "model/flinkExecutor.jar", "components/flink", "components/common"]
{{- else if eq .Values.nussknacker.mode "streaming-lite" -}}
["model/defaultModel.jar", "components/lite/liteBase.jar", "components/lite/liteKafka.jar", "components/common"]
{{- else if eq .Values.nussknacker.mode "request-response" -}}
["model/defaultModel.jar", "components/lite/liteBase.jar", "components/lite/liteRequestResponse.jar", "components/common"]
{{- else -}}
{{- fail "Value for .Values.nussknacker.mode is not supported. Supported modes are: flink, streaming-lite and request-response" }}
{{- end -}}
{{- end -}}


{{- define "nussknacker.influxDbConfig" -}}
    {
      "user": ${INFLUXDB_USER}
      "password": ${INFLUXDB_PASSWORD}
      "influxUrl": "{{- include "nussknacker.influxUrl" . -}}/query"
      "database": "nussknacker"
      {{- if eq .Values.nussknacker.mode "flink" -}}
      {{/* We use prometheus reporter     */}}
      metricsConfig: {  "countField": "gauge"}
      {{- end -}}
    }
{{- end -}}

{{- define "nussknacker.scenarioType" -}}
{{- if eq .Values.nussknacker.mode "flink" -}}
StreamMetaData
{{- else if eq .Values.nussknacker.mode "streaming-lite" -}}
LiteStreamMetaData
{{- else if eq .Values.nussknacker.mode "request-response" -}}
RequestResponseMetaData
{{- end -}}
{{- end -}}

{{- define "nussknacker.customLogbackConfig" -}}
{{ or .Values.designerLogbackConfig .Values.runtimeLogbackConfig}}
{{- end -}}

{{/*
Taken from https://github.com/bitnami/charts/blob/9401e13316992c36b0e33de75d5f249645a2924e/bitnami/common/templates/_tplvalues.tpl
*/}}
{{- define "common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}
