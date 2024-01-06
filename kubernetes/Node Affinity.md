# Kubernetes Node Affinity

## Introduction
Node affinity in Kubernetes allows you to specify rules for pod scheduling based on node properties. It helps in influencing which nodes a pod is eligible to be scheduled on.

## How to Set Node Affinity for Pods

### Define Node Affinity in Pod Specification
To set node affinity for a pod, define node affinity rules in the pod's YAML definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: <node_label_key>
            operator: In
            values:
            - <node_label_value>
```

In this example:
- `<node_label_key>`: Specifies the key of the node label used for node affinity.
- `<node_label_value>`: Specifies the value of the node label.

### Available Node Affinity Operators
- **In**: Specifies that the label key's value must be in the given list of values.
- **NotIn**: Specifies that the label key's value must not be in the given list of values.
- **Exists**: Specifies that the label key must exist on the node.
- **DoesNotExist**: Specifies that the label key must not exist on the node.

## How to Use Node Affinity Rules within a Pod

### Set Node Affinity Rules in Pod Specification
Define node affinity rules in the pod's YAML definition as explained earlier to guide pod scheduling based on node properties.

## Useful Commands for Node Affinity

### Get Nodes and Their Labels
```bash
kubectl get nodes --show-labels
```

### List Pods with Node Affinity Rules
```bash
kubectl get pods -o=custom-columns=NAME:.metadata.name,AFFINITY:.spec.affinity.nodeAffinity
```

### Describe Node Affinity for a Pod
```bash
kubectl describe pod <pod_name> | grep -i nodeAffinity
```