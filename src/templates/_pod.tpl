{{- define "nussknacker.pod" -}}
{{- $root := . -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "nussknacker.serviceAccountName" . }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
containers:
  - name: {{ .Chart.Name }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    image: "{{ .Values.image.repository }}:{{ include "nussknacker.imageTag" . }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    volumeMounts:
      - name: config
        mountPath: /etc/nussknacker
      {{- if (include "nussknacker.customLogbackConfig" .) }}
      - name: logging-config
        mountPath: /etc/logging
      {{- end }}
      {{- if .Values.persistence.enabled }}
      - name: storage
        mountPath: /opt/nussknacker/storage
        subPath: {{ .Values.persistence.subPath }}
      {{- end }}
      {{- if .Values.additionalVolumeMounts }}
        {{- toYaml .Values.additionalVolumeMounts | nindent 6 -}}
      {{- end }}
    env:
      - name: JDK_JAVA_OPTIONS
        value: {{ .Values.nussknacker.javaOpts }}
      - name: CONFIG_FILE
        value: {{ .Values.nussknacker.configFile }}
      - name: HELM_RELEASE_NAME
        value: {{ .Release.Name }}
      {{- if .Values.designerLogbackConfig }}
      - name: LOGBACK_FILE
        value: "/etc/logging/logback.xml"
      {{- end }}
      {{- if .Values.runtimeLogbackConfig }}
      - name: RUNTIME_LOGBACK_FILE
        value: "/etc/logging/runtime-logback.xml"
      {{- end }}
      {{- if .Values.prometheusMetrics.enabled }}
      - name: PROMETHEUS_METRICS_PORT
        value: {{ .Values.prometheusMetrics.port | quote }}
      {{- end }}
      {{- if .Values.postgresql.enabled }}
      - name: DB_PASSWORD
        valueFrom:
          secretKeyRef:
            name: '{{- include "postgresql.secretName" .Subcharts.postgresql }}'
            key: postgres-password
      {{- end -}}
      {{- if .Values.influxdb.enabled }}
      - name: INFLUXDB_PASSWORD
        valueFrom:
          secretKeyRef:
            name: '{{- include "influxdb.fullname" .Subcharts.influxdb }}-auth'
            key: influxdb-password
      - name: INFLUXDB_USER
        valueFrom:
          secretKeyRef:
            name: '{{- include "influxdb.fullname" .Subcharts.influxdb }}-auth'
            key: influxdb-user
      {{- end -}}
      {{- if .Values.extraEnv -}}
        {{- .Values.extraEnv | toYaml | nindent 6 -}}
      {{- end }}
    ports:
      - name: http
        containerPort: 8080
        protocol: TCP
      {{ if .Values.persistence.enabled }}
      - name: hsql
        containerPort: 9001
        protocol: TCP
      {{ end }}
      {{ if .Values.prometheusMetrics.enabled }}
      - name: prometheus
        containerPort: {{ .Values.prometheusMetrics.port }}
        protocol: TCP
      {{ end }}
    livenessProbe:
      httpGet:
        path: /
        port: http
      periodSeconds: {{ .Values.deployment.livenessProbe.periodSeconds }}
      failureThreshold: {{ .Values.deployment.livenessProbe.failureThreshold }}
      timeoutSeconds: {{ .Values.deployment.livenessProbe.timeoutSeconds }}
    startupProbe:
      httpGet:
        path: /
        port: http
      periodSeconds: {{ .Values.deployment.startupProbe.periodSeconds }}
      failureThreshold: {{ .Values.deployment.startupProbe.failureThreshold }}
      timeoutSeconds: {{ .Values.deployment.startupProbe.timeoutSeconds }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
{{- if .Values.sidecarContainers -}}
  {{- toYaml .Values.sidecarContainers | nindent 2 -}}
{{- end }}
{{- with .Values.nussknackerInitContainers }}
initContainers:
  {{- toYaml . | nindent 4 }}
{{- end }}
volumes:
  - name: config
    configMap:
      name: {{ include "nussknacker.fullname" . }}
  {{- if (include "nussknacker.customLogbackConfig" .) }}
  - name: logging-config
    configMap:
      name: {{ include "nussknacker.fullname" . }}-logging-conf
  {{- end }}
  {{- if not .Values.statefulSet.enabled }}
  - name: storage
  {{- if .Values.persistence.enabled }}
    persistentVolumeClaim:
      claimName: {{ .Values.persistence.existingClaim | default (include "nussknacker.fullname" .) }}
  {{- else }}
    emptyDir: {}
  {{- end }}
  {{- end }}
  {{- if .Values.additionalVolumes }}
    {{- toYaml .Values.additionalVolumes | nindent 2 -}}
  {{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
