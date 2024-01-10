# Kubernetes Persistent Volumes and Persistent Volume Claims

## Introduction

In Kubernetes, Persistent Volumes (PVs) and Persistent Volume Claims (PVCs) enable the decoupling of storage provision from pod specification, providing more flexibility and abstraction in managing storage. PVs represent storage resources in a cluster, while PVCs are requests made by pods for storage.

### Persistent Volumes (PVs)

PVs are cluster-wide resources that represent storage, such as physical disks, cloud storage, or network storage. They are provisioned by administrators and can be dynamically provisioned or statically configured.

### Persistent Volume Claims (PVCs)

PVCs are requests for storage by users or applications. They consume PV resources by specifying the access mode, storage requirements, and other attributes needed from the underlying PV.

## Sample Configuration

### 1. Create a Persistent Volume (PV)

Here's an example of a Persistent Volume configuration:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: "/mnt/data"
```

Explanation:
- `name`: Name of the Persistent Volume.
- `capacity`: Desired capacity of the volume.
- `volumeMode`: Filesystem or Block mode.
- `accessModes`: Modes such as ReadWriteOnce, ReadOnlyMany, ReadWriteMany.
- `persistentVolumeReclaimPolicy`: Policy when the PV is released.
- `storageClassName`: Reference to a StorageClass.
- `hostPath`: Specifies a path on the host for the storage.

### 2. Create a Persistent Volume Claim (PVC)

Now, let's create a Persistent Volume Claim that requests storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  storageClassName: manual
```

Explanation:
- `name`: Name of the Persistent Volume Claim.
- `accessModes`: Requested access mode.
- `resources.requests.storage`: Required storage amount.
- `storageClassName`: References the StorageClass the PVC should use.

### 3. Using the PVC in a Pod

Finally, a Pod can consume the PVC by referencing it in its volume specification:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
    - name: example-container
      image: nginx
      volumeMounts:
        - mountPath: "/mnt/data"
          name: data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: example-pvc
```

Explanation:
- `volumeMounts`: Defines where the volume is mounted within the container.
- `volumes`: Specifies the PVC to be used by the Pod.

[[Storage volumes]]