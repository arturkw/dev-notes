# Kubernetes Resource Limits

## Introduction
Resource Limits in Kubernetes allow administrators to control the amount of CPU and memory that a container or pod can use. Setting resource limits ensures fairness and prevents any single pod from monopolizing resources.

## How to Set Resource Limits

### Set Resource Limits in Pod Definition
To set resource limits for a pod, specify them in the pod's YAML definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    resources:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "500m"
        memory: "500Mi"
```

In this example:
- `limits` define the maximum amount of CPU and memory that the container can use.
- `requests` define the amount of CPU and memory that the container initially requests.

### Apply Resource Limits to Deployments or StatefulSets
You can also set resource limits in Deployments or StatefulSets by specifying them in the pod template section.

## How to Use Resource Limits within a Pod

### Check Resource Limits in a Pod
To view the resource limits set for a pod:
```bash
kubectl describe pod <pod_name>
```

### View Resource Usage in a Pod
To check the resource usage of a pod:
```bash
kubectl top pod <pod_name>
```

## Useful Commands for Resource Limits

### List Pods with Resource Limits
```bash
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,LIMITS:.spec.containers[*].resources.limits
```

### List Resource Quotas
```bash
kubectl get resourcequotas
```

### Describe Resource Quota Details
```bash
kubectl describe resourcequota <resource_quota_name>
```

### Delete Resource Quota
```bash
kubectl delete resourcequota <resource_quota_name>
```