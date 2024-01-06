# Kubernetes Service Accounts

## Introduction
Service Accounts in Kubernetes provide an identity for pods that need to interact with other parts of the Kubernetes cluster. They are used to authenticate and authorize requests made by pods to other cluster components.

## How to Create a Service Account

### Create a Service Account
To create a service account, use the following command:
```bash
kubectl create serviceaccount <service_account_name>
```

### Describe a Service Account
To view details about a service account:
```bash
kubectl describe serviceaccount <service_account_name>
```

## How to Use Service Accounts within a Pod

### Attach a Service Account to a Pod
You can attach a service account to a pod by specifying it in the pod's YAML definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  serviceAccountName: <service_account_name>
  containers:
  - name: myapp-container
    image: myapp:latest
```

### Accessing Service Account from Pod
Inside the pod, the service account credentials are available through the default service account path:
```bash
/var/run/secrets/kubernetes.io/serviceaccount/
```

## Useful Commands for Service Accounts

### List Service Accounts
```bash
kubectl get serviceaccounts
```

### List Pods and Their Service Accounts
```bash
kubectl get pods -o custom-columns=POD:metadata.name,SERVICE_ACCOUNT:spec.serviceAccountName
```

### Delete a Service Account
```bash
kubectl delete serviceaccount <service_account_name>
```