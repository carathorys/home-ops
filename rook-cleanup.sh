#!/bin/bash

NODES=("avarath" "hummianet" "arriron" "widagoth")

for i in "${NODES[@]}"
do
echo "Cleanup rook on $i"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: disk-clean
spec:
  restartPolicy: Never
  nodeName: $i
  volumes:
  - name: rook-data-dir
    hostPath:
      path: /var/lib/rook
  containers:
  - name: disk-clean
    image: busybox
    securityContext:
      privileged: true
    volumeMounts:
    - name: rook-data-dir
      mountPath: /node/rook-data
    command: ["/bin/sh", "-c", "rm -rf /node/rook-data/*"]
EOF

kubectl wait --timeout=900s --for=jsonpath='{.status.phase}=Succeeded' pod disk-clean

kubectl delete pod disk-clean
done