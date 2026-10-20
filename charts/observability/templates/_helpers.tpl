{{/* <release>-otel-collector: o chart "microservice" monta esta URL para exportar os traces. */}}
{{- define "observability.collectorName" -}}
{{- printf "%s-otel-collector" .Release.Name }}
{{- end }}

{{- define "observability.jaegerName" -}}
{{- printf "%s-jaeger" .Release.Name }}
{{- end }}

{{- define "observability.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}
