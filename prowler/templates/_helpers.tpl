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
