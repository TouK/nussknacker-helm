{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "nussknacker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
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

{{- define "nussknacker.kafkaUrl" -}}
{{- if .Values.kafka.enabled -}}
    {{ include "kafka.fullname" (dict "Chart" (dict "Name" "kafka") "Values" .Values.kafka "Release" .Release "Capabilities" .Capabilities) }}:9092
{{- else -}}
    {{ required "Enable kafka or provide a valid .Values.kafka.url entry!" ( tpl .Values.kafka.url . ) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.schemaRegistryUrl" -}}
{{- if index .Values "schema-registry" "enabled" -}}
    http://{{ include "schema-registry.fullname" (dict "Chart" (dict "Name" "schema-registry") "Values" ( index .Values "schema-registry" ) "Release" .Release "Capabilities" .Capabilities) }}:8081
{{- else -}}
    {{ required "Enable schema-registry or provide a valid .Values.schema-registry.url entry!" ( tpl ( index .Values "schema-registry" "url" ) . ) }}
{{- end -}}
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

{{- define "nussknacker.grafanaUrl" -}}
    {{/* TODO: configurable path, proper ingress configuration   */}}
    {{- $domain := required "Provide a domain name for grafana" .Values.ingress.domain -}}
    {{- $fullName := default (include "nussknacker.fullname" .) .Values.ingress.host -}}
    {{- printf "https://%s.%s/grafana" $fullName $domain -}}
{{- end -}}

{{/* TODO: handling custom port */}}
{{- define "nussknacker.influxUrl" -}}
    http://{{ include "influxdb.fullname" (dict "Chart" (dict "Name" "influxdb") "Values" .Values.influxdb "Release" .Release "Capabilities" .Capabilities) }}:8086
{{- end -}}

{{- define "nussknacker.influxDbConfig" -}}
    {
      "user": "admin"
      "password": "admin"
      "influxUrl": "{{- include "nussknacker.influxUrl" . -}}/query"
      "database": "nussknacker"
      {{/* We use prometheus reporter     */}}
      metricsConfig: {  "countField": "gauge"}
    }
{{- end -}}


{{- define "nussknacker.hermesUiManagementTab" -}}
{{- if .Values.hermes.enabled -}}
    {
      "name": "Hermes"
      "id": "hermes"
      "url": "{{ include "hermes.management.svcExternalUrl" (dict "Chart" (dict "Name" "hermes") "Values" .Values.hermes "Release" .Release "Capabilities" .Capabilities) }}"
    }
{{- end -}}
{{- end -}}
