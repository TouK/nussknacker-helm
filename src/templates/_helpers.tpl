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
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
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
    {{ include "kafka.fullname" (dict "Chart" (dict "Name" "kafka") "Values" .Values.hermes "Release" .Release "Capabilities" .Capabilities) }}:9092
{{- else -}}
    {{ required "Enable kafka or provide a valid .Values.kafka.url entry!" ( tpl .Values.kafka.url . ) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.schemaRegistryUrl" -}}
{{- if index .Values "schema-registry" "enabled" -}}
    http://{{ include "schema-registry.fullname" (dict "Chart" (dict "Name" "schema-registry") "Values" .Values.hermes "Release" .Release "Capabilities" .Capabilities) }}:8081
{{- else -}}
    {{ required "Enable schema-registry or provide a valid .Values.schema-registry.url entry!" ( tpl ( index .Values "schema-registry" "url" ) . ) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.flinkJobManagerUrl" -}}
{{- if .Values.flink.enabled -}}
    http://{{ include "flink.fullname" (dict "Chart" (dict "Name" "flink") "Values" .Values.hermes "Release" .Release "Capabilities" .Capabilities) }}-jobmanager-rest:8081
{{- else -}}
    {{ required "Enable flink or provide a valid .Values.flink.job-manager-url entry!" ( tpl ( index .Values "flink" "job-manager-url" ) . ) }}
{{- end -}}
{{- end -}}

{{- define "nussknacker.flinkTaskManagerUrl" -}}
{{- if .Values.flink.enabled -}}
    {{ include "flink.fullname" (dict "Chart" (dict "Name" "flink") "Values" .Values.hermes "Release" .Release "Capabilities" .Capabilities) }}-taskmanager:6122
{{- else -}}
    {{ required "Enable flink or provide a valid .Values.flink.task-manager-url entry!" ( tpl ( index .Values "flink" "task-manager-url" ) . ) }}
{{- end -}}
{{- end -}}
