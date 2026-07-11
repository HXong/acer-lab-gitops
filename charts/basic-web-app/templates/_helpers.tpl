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
Ownership labels used by the Acer Lab dashboard.
*/}}
{{- define "basic-web-app.ownershipLabels" -}}
{{- $owner := .Values.owner | default dict -}}
acer-lab.io/owner: {{ .Values.owner.name | default "unassigned" | quote }}
acer-lab.io/team: {{ .Values.owner.team | default "homelab" | quote }}
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
Top-level resource labels, including ownership.
*/}}
{{- define "basic-web-app.resourceLabels" -}}
{{ include "basic-web-app.labels" . }}
{{ include "basic-web-app.ownershipLabels" . }}
{{- end }}

{{/*
Selector labels.
Keep this stable and minimal.
*/}}
{{- define "basic-web-app.selectorLabels" -}}
app: {{ include "basic-web-app.name" . }}
{{- end }}
