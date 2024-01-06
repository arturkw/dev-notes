# Kubernetes Secrets

## Short Description
Secrets in Kubernetes allow secure storage of sensitive information, such as passwords, OAuth tokens, and SSH keys. This README provides instructions on creating, using, encoding, decoding, and utilizing secrets to configure pods.

## How to Use Secrets

Kubernetes Secrets can be used in various ways:

- Mounting secrets as files inside pods.
- Using secrets as environment variables in pod configurations.
- Accessing secrets from the Kubernetes API.

## Useful Commands

### Create a Secret from Literal Values
```bash
kubectl create secret generic <secret_name> --from-literal=key1=value1 --from-literal=key2=value2
```

### Create a Secret from a File
```bash
kubectl create secret generic <secret_name> --from-file=<path/to/file>
```

### List Secrets
```bash
kubectl get secrets
```

### Describe a Secret
```bash
kubectl describe secret <secret_name>
```

### Delete a Secret
```bash
kubectl delete secret <secret_name>
```

### Encode a Secret Value
```bash
echo -n "my_secret_value" | base64
```

### Decode a Secret Value
```bash
echo -n "c2VjcmV0X3ZhbHVl" | base64 --decode
```

## Using Secrets to Configure a Pod

### Configuring Environment Variables from Secrets

You can inject Secret data as environment variables into a Pod. Here's an example YAML configuration:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    env:
    - name: SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: sample-secret
          key: secret_key
```

### Using Secrets as Files in a Pod

You can also use Secret data as files within a Pod. Here's an example YAML configuration:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-file-pod
spec:
  containers:
  - name: myapp-container
    image: myapp:latest
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secret
  volumes:
  - name: secret-volume
    secret:
      secretName: sample-secret
```