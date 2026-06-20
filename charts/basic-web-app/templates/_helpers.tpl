{{/*
Application name from values.
*/}}
{{- define "basic-web-app.name" -}}
{{- .Values.app.name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Application namespace from values.
*/}}
{{- define "basic-web-app.namespace" -}}
{{- .Values.app.namespace | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "basic-web-app.labels" -}}
app: {{ include "basic-web-app.name" . }}
app.kubernetes.io/name: {{ include "basic-web-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.app.partOf | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Selector labels.
Keep this stable and minimal.
*/}}
{{- define "basic-web-app.selectorLabels" -}}
app: {{ include "basic-web-app.name" . }}
{{- end }}
