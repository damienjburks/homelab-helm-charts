{{/*
Wazuh agent init containers.
Usage: {{ include "sonarqube.wazuhInitContainers" (dict "root" . "component" "sonarqube") | nindent 8 }}
*/}}
{{- define "sonarqube.wazuhInitContainers" -}}
- name: seed-wazuh-agent-state
  image: {{ .root.Values.wazuh.agentImage }}
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
- name: create-shared-logs
  image: busybox:1.36
  imagePullPolicy: IfNotPresent
  command: ["sh", "-c", "touch /shared-logs/{{ .component }}.log"]
  volumeMounts:
    - name: shared-logs
      mountPath: /shared-logs
{{- end -}}

{{/*
Wazuh agent sidecar container.
Usage: {{ include "sonarqube.wazuhSidecar" (dict "root" . "component" "sonarqube") | nindent 8 }}
*/}}
{{- define "sonarqube.wazuhSidecar" -}}
- name: wazuh-agent
  image: {{ .root.Values.wazuh.agentImage }}
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
    - name: shared-logs
      mountPath: /shared-logs
    - name: wazuh-agent-config
      mountPath: /wazuh-config-mount/etc/ossec.conf
      subPath: ossec.conf
{{- end -}}


{{/*
Wazuh-related volumes.
Usage: {{ include "sonarqube.wazuhVolumes" (dict "root" . "component" "sonarqube") | nindent 8 }}
*/}}
{{- define "sonarqube.wazuhVolumes" -}}
- name: shared-logs
  emptyDir: {}
- name: wazuh-agent-data
  persistentVolumeClaim:
    claimName: {{ printf "%s-%s-wazuh-pvc" .root.Release.Name .component | quote }}
- name: wazuh-agent-config
  configMap:
    name: {{ printf "%s-%s-wazuh-agent-config" .root.Release.Name .component }}
{{- end -}}

{{/*
Shared-logs volumeMount for the main app container.
Usage: {{ include "sonarqube.wazuhAppVolumeMount" . | nindent 12 }}
*/}}
{{- define "sonarqube.wazuhAppVolumeMount" -}}
- name: shared-logs
  mountPath: /shared-logs
{{- end -}}
