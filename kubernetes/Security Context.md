# Kubernetes Security Context

## Purpose
Security Context in Kubernetes allows administrators to define and control the security settings and privileges for pods and containers. It enables setting permissions, privileges, capabilities, and other security-related configurations to enhance the security posture of the Kubernetes cluster.

You can define security context settings directly in the pod specification. Here's an example of how to set security context for a pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-pod
spec:
  securityContext:
    runAsUser: 1000
    capabilities:
      add: ["NET_ADMIN"]
  containers:
  - name: myapp-container
    image: myapp:latest
```

In this example:
- `runAsUser` sets the user ID under which the container runs.
- `capabilities` adds additional capabilities to the container.

### Setting Security Context in Container Definition

Security context settings can also be defined within a container specification. Here's an example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-container-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    securityContext:
      runAsUser: 1000
      capabilities:
        add: ["NET_ADMIN"]
```

## Useful Commands

### Get Security Context for a Pod
```bash
kubectl get pod <pod_name> -o=jsonpath='{.spec.securityContext}'
```

### Describe Pod Security Context
```bash
kubectl describe pod <pod_name> | grep -i securityContext
```

### List Pods with Security Context
```bash
kubectl get pods --show-labels -o wide
```

### Set Security Context in Pod Definition
```bash
kubectl apply -f <pod_security_context.yaml>
```

### Update Security Context for a Running Pod
```bash
kubectl patch pod <pod_name> -p '{"spec":{"securityContext":{"runAsUser":1001}}}'
```

