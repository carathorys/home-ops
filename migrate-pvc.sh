#!/bin/bash

# See https://justyn.io/til/migrate-kubernetes-pvc-to-another-pvc/ for details

set -exu

src=$1
dst=$2

echo "Creating job yaml"
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-pv-$src
  namespace: home-assistant
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: debian
        command: [ "/bin/bash", "-c" ]
        args:
          -
            apt-get update && apt-get install -y rsync &&
            ls -lah /src_vol /dst_vol &&
            df -h &&
            rsync -avPS --delete /src_vol/ /dst_vol/ &&
            ls -lah /dst_vol/ &&
            du -shxc /src_vol/ /dst_vol/
        volumeMounts:
        - mountPath: /src_vol
          name: src
          readOnly: true
        - mountPath: /dst_vol
          name: dst
      restartPolicy: Never
      volumes:
      - name: src
        persistentVolumeClaim:
          claimName: $src
      - name: dst
        persistentVolumeClaim:
          claimName: $dst
  backoffLimit: 1
EOF

# kubectl wait --timeout=900s --for=jsonpath='{.status.phase}=Succeeded' --namespace=home-assistant job migrate-pv-$src
# kubectl delete job  --namespace=home-assistant migrate-pv-$src
