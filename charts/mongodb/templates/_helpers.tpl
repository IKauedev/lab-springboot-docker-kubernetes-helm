{{/* <release>-mongodb: o mesmo nome que o chart "microservice" usa para achar o host e o Secret. */}}
{{- define "mongodb.fullname" -}}
{{- printf "%s-mongodb" .Release.Name }}
{{- end }}

{{- define "mongodb.selectorLabels" -}}
app.kubernetes.io/name: mongodb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "mongodb.labels" -}}
{{ include "mongodb.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}
