{{/*
Per-subfolder hostPath volumeMounts. Mounts each configured repo subfolder as a
sibling under mountRoot so the Jupyter view stays clean. Indented for a
container's `volumeMounts:` list (10 spaces).
*/}}
{{- define "spark.hostMounts" -}}
{{- if and .Values.hostMount.enabled .Values.hostMount.hostPath }}
{{- range concat .Values.hostMount.paths (list .Values.hostMount.warehouse) | uniq }}
- name: mount-{{ . | replace "/" "-" }}
  mountPath: {{ printf "%s/%s" $.Values.hostMount.mountRoot . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
spark.sql.warehouse.dir: the shared, host-mounted warehouse folder when mounts
are on (so writes by executors and reads by the driver hit the same files).
*/}}
{{- define "spark.warehouseDir" -}}
{{- if and .Values.hostMount.enabled .Values.hostMount.hostPath -}}
{{ printf "%s/%s" .Values.hostMount.mountRoot .Values.hostMount.warehouse }}
{{- end -}}
{{- end -}}

{{/*
Matching hostPath volumes. Indented for a pod's `volumes:` list (8 spaces).
*/}}
{{- define "spark.hostVolumes" -}}
{{- if and .Values.hostMount.enabled .Values.hostMount.hostPath }}
{{- range concat .Values.hostMount.paths (list .Values.hostMount.warehouse) | uniq }}
- name: mount-{{ . | replace "/" "-" }}
  hostPath:
    path: {{ printf "%s/%s" $.Values.hostMount.hostPath . | quote }}
    type: DirectoryOrCreate
{{- end }}
{{- end }}
{{- end -}}
