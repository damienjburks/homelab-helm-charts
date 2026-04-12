{{/*
Wazuh agent init containers.
Usage: {{ include "cloudflared.wazuhInitContainers" . | nindent 8 }}
*/}}
{{- define "cloudflared.wazuhInitContainers" -}}
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
  command: ["sh", "-c", "touch /shared-logs/cloudflared.log"]
  volumeMounts:
    - name: shared-logs
      mountPath: /shared-logs
{{- end -}}
