{{/* Nome curto do serviço. Com alias de dependência, .Chart.Name continua "microservice", por isso o nameOverride. */}}
{{- define "microservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Nome dos recursos: <release>-<nome>. Dois releases não colidem no mesmo namespace. */}}
{{- define "microservice.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "microservice.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "microservice.labels" -}}
{{ include "microservice.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "microservice.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/* Nome do Secret/host do MongoDB criado pelo chart "mongodb" no mesmo release. */}}
{{- define "microservice.mongoName" -}}
{{- printf "%s-mongodb" .Release.Name }}
{{- end }}
