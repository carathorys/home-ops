#!/bin/bash

kubectl --namespace rook-ceph patch cephcluster rook-ceph --type merge -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}'
kubectl delete storageclasses ceph-block ceph-bucket ceph-filesystem
kubectl --namespace rook-ceph delete cephblockpools ceph-blockpool
kubectl --namespace rook-ceph delete cephobjectstore ceph-objectstore
kubectl --namespace rook-ceph delete cephfilesystemsubvolumegroup ceph-filesystem-csi
kubectl --namespace rook-ceph delete cephfilesystem ceph-filesystem
kubectl --namespace rook-ceph delete cephcluster rook-ceph

helm --namespace rook-ceph uninstall rook-ceph-cluster
helm --namespace rook-ceph uninstall rook-ceph-operator

kubectl delete crds cephblockpools.ceph.rook.io cephbucketnotifications.ceph.rook.io cephbuckettopics.ceph.rook.io \
                      cephclients.ceph.rook.io cephclusters.ceph.rook.io cephfilesystemmirrors.ceph.rook.io \
                      cephfilesystems.ceph.rook.io cephfilesystemsubvolumegroups.ceph.rook.io \
                      cephnfses.ceph.rook.io cephobjectrealms.ceph.rook.io cephobjectstores.ceph.rook.io \
                      cephobjectstoreusers.ceph.rook.io cephobjectzonegroups.ceph.rook.io cephobjectzones.ceph.rook.io \
                      cephrbdmirrors.ceph.rook.io objectbucketclaims.objectbucket.io objectbuckets.objectbucket.io \
                      cephblockpoolradosnamespaces.ceph.rook.io cephcosidrivers.ceph.rook.io


NODES=("avarath" "hummianet" "arriron" "widagoth")

for i in "${NODES[@]}"
do
echo "Cleanup rook on $i"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: disk-clean-$i
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
done


for i in "${NODES[@]}"
do
kubectl wait --timeout=900s --for=jsonpath='{.status.phase}=Succeeded' pod disk-clean-$i

kubectl delete pod disk-clean-$i

done