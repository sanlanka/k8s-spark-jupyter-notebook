{{/*
Per-subfolder hostPath volumeMounts. Mounts each configured repo subfolder as a
sibling under mountRoot so the Jupyter view stays clean. Indented for a
container's `volumeMounts:` list (10 spaces).
*/}}
{{- define "spark.hostMounts" -}}
{{- if and .Values.hostMount.enabled .Values.hostMount.hostPath }}
{{- range .Values.hostMount.paths }}
- name: mount-{{ . | replace "/" "-" }}
  mountPath: {{ printf "%s/%s" $.Values.hostMount.mountRoot . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Matching hostPath volumes. Indented for a pod's `volumes:` list (8 spaces).
*/}}
{{- define "spark.hostVolumes" -}}
{{- if and .Values.hostMount.enabled .Values.hostMount.hostPath }}
{{- range .Values.hostMount.paths }}
- name: mount-{{ . | replace "/" "-" }}
  hostPath:
    path: {{ printf "%s/%s" $.Values.hostMount.hostPath . | quote }}
    type: Directory
{{- end }}
{{- end }}
{{- end -}}
