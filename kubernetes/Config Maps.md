# Kubernetes ConfigMaps

## Short Description
ConfigMaps in Kubernetes provide a way to decouple configuration artifacts from container images. They allow you to manage configuration data separately and inject it into pods at runtime, enabling better portability and flexibility in deployments.

## Useful Commands

### Create a ConfigMap from Literal Values
```bash
kubectl create configmap <configmap_name> --from-literal=key1=value1 --from-literal=key2=value2
```

### Create a ConfigMap from a File
```bash
kubectl create configmap <configmap_name> --from-file=<path/to/file>
```

### List ConfigMaps
```bash
kubectl get configmaps
```

### Describe a ConfigMap
```bash
kubectl describe configmap <configmap_name>
```

### Delete a ConfigMap
```bash
kubectl delete configmap <configmap_name>
```
## Using ConfigMaps to Configure a Pod

### Configuring Environment Variables from ConfigMap

You can inject ConfigMap data as environment variables into a Pod. Here's an example YAML configuration:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    env:
    - name: KEY1
      valueFrom:
        configMapKeyRef:
          name: sample-configmap
          key: key1
    - name: KEY2
      valueFrom:
        configMapKeyRef:
          name: sample-configmap
          key: key2
```

### Using ConfigMap Data as Files in a Pod

You can also use ConfigMap data as files within a Pod. Here's an example YAML configuration:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-file-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: sample-configmap
```

Adjust these configurations based on your specific use case and application requirements.