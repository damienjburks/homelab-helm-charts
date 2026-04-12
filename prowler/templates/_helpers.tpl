{{- define "prowler.nodeAffinity" -}}
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                {{- range .Values.nodeAffinity.requiredNodes }}
                - {{ . }}
                {{- end }}
{{- end }}

{{/*
Wazuh agent init containers — seeds agent state and fixes permissions.
Usage: {{ include "prowler.wazuhInitContainers" (dict "root" . "component" "api") | nindent 8 }}
*/}}
{{- define "prowler.wazuhInitContainers" -}}
- name: seed-wazuh-agent-state
  image: wazuh/wazuh-agent:4.14.4
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-lc"]
  args:
    - |
      set -euo pipefail
      mkdir -p /agent
      if [ ! -d /agent/bin ] && [ ! -f /agent/etc/ossec.conf ]; then
        echo "[init] Seeding /var/ossec into PVC..."
        tar -C /var/ossec -cf - . | tar -C /agent -xpf -
      else
        echo "[init] Existing Wazuh agent state found; skipping seed."
      fi
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
      subPath: prowler/wazuh/{{ .component }}
- name: fix-wazuh-agent-perms
  image: busybox:1.36
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-lc"]
  args:
    - |
      set -e
      for d in etc logs queue var rids tmp active-response; do
        [ -d "/agent/$d" ] && chown -R 999:999 "/agent/$d"
      done
      [ -d /agent/bin ] && chown -R 0:0 /agent/bin || true
      [ -d /agent/lib ] && chown -R 0:0 /agent/lib || true
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
      subPath: prowler/wazuh/{{ .component }}
{{- end -}}

{{/*
Wazuh agent sidecar container.
Usage: {{ include "prowler.wazuhSidecar" (dict "root" . "component" "api") | nindent 8 }}
*/}}
{{- define "prowler.wazuhSidecar" -}}
- name: wazuh-agent
  image: wazuh/wazuh-agent:4.14.4
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 0
  env:
    - name: WAZUH_MANAGER
      value: {{ .root.Values.wazuh.manager | quote }}
    - name: WAZUH_AGENT_NAME
      value: {{ printf "%s-%s" .root.Release.Name .component | quote }}
    - name: WAZUH_AGENT_GROUP
      value: {{ .root.Values.wazuh.group | default "k8s" | quote }}
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /var/ossec
      subPath: prowler/wazuh/{{ .component }}
    - name: shared-logs
      mountPath: /shared-logs
    - name: wazuh-agent-config
      mountPath: /wazuh-config-mount/etc/ossec.conf
      subPath: ossec.conf
{{- end -}}

{{/*
Wazuh-related volumes for a deployment.
Usage: {{ include "prowler.wazuhVolumes" (dict "root" . "component" "api") | nindent 8 }}
*/}}
{{- define "prowler.wazuhVolumes" -}}
- name: shared-logs
  emptyDir: {}
- name: wazuh-agent-data
  persistentVolumeClaim:
    claimName: {{ .root.Values.wazuh.persistence.existingClaim | quote }}
- name: wazuh-agent-config
  configMap:
    name: {{ printf "%s-%s-wazuh-agent-config" .root.Release.Name .component }}
{{- end -}}

{{/*
Shared-logs volumeMount for the main app container.
Usage: {{ include "prowler.wazuhAppVolumeMount" . | nindent 12 }}
*/}}
{{- define "prowler.wazuhAppVolumeMount" -}}
- name: shared-logs
  mountPath: /shared-logs
{{- end -}}
