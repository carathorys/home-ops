machine:
  certSANs:
    - "127.0.0.1"
    - "192.168.1.1"
    - "homelab.{{ .Data.SECRET_DOMAIN }}"
---
apiVersion: v1alpha1
kind: KubeAPIServerConfig
certExtraSANs:
  - "127.0.0.1"
  - "192.168.1.1"
  - "homelab.{{ .Data.SECRET_DOMAIN }}"
