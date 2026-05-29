{{- define "pharma-app.name" -}}
{{- .Values.appName | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pharma-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "pharma-app.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pharma-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "pharma-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
