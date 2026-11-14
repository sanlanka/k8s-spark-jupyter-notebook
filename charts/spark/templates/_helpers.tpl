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
{{- range .Values.hostMount.extraPaths }}
- name: extra-{{ .name }}
  mountPath: {{ printf "%s/%s" $.Values.hostMount.mountRoot .name }}
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
{{- range .Values.hostMount.extraPaths }}
{{- if not (hasPrefix "/" .hostPath) }}
{{- fail (printf "hostMount.extraPaths: hostPath for %q must be absolute, got %q" .name .hostPath) }}
{{- end }}
- name: extra-{{ .name }}
  hostPath:
    path: {{ .hostPath | quote }}
    # Directory, not DirectoryOrCreate: a typo'd path fails loudly instead of
    # silently mounting a new empty folder.
    type: Directory
{{- end }}
{{- end -}}

{{/*
Driver-side Spark settings as a key -> value dict: the shared warehouse dir,
the Delta Connect plugins (Spark Connect only), then the user's sparkConf last
so it can override anything. Used by Jupyter (spark-defaults lines) and Spark
Connect (--conf args).
*/}}
{{- define "spark.driverConf" -}}
{{- $conf := dict -}}
{{- with include "spark.warehouseDir" . }}{{ $_ := set $conf "spark.sql.warehouse.dir" . }}{{ end -}}
{{- range $k, $v := .Values.sparkConf }}{{ $_ := set $conf $k (toString $v) }}{{ end -}}
{{- toYaml $conf -}}
{{- end -}}
