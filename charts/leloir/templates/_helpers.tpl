{{/* Name helpers */}}
{{- define "leloir.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "leloir.fullname" -}}
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

{{- define "leloir.labels" -}}
app.kubernetes.io/name: {{ include "leloir.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: leloir
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "leloir.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* Control plane component name */}}
{{- define "leloir.controlplane.fullname" -}}
{{- printf "%s-controlplane" (include "leloir.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "leloir.gateway.fullname" -}}
{{- printf "%s-gateway" (include "leloir.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "leloir.memory.fullname" -}}
{{- printf "%s-memory-mcp" (include "leloir.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "leloir.receiver.fullname" -}}
{{- printf "%s-webhook-receiver" (include "leloir.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Database DSN. Prefers an external DSN (or its Secret) when postgresql.enabled is
false; otherwise builds one against the bundled Bitnami Postgres. Postgres host
follows Bitnami's naming: <release>-postgresql.
*/}}
{{- define "leloir.postgresHost" -}}
{{- printf "%s-postgresql.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- end -}}

{{/* The Secret name that holds the DSN (either external, or the chart-managed one). */}}
{{- define "leloir.dsnSecret" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- printf "%s-db" (include "leloir.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "leloir.dsnSecretKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretKey -}}
{{- else -}}
dsn
{{- end -}}
{{- end -}}
