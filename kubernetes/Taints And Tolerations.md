# Kubernetes Taints and Tolerations

## Introduction
Taints and tolerations in Kubernetes help control which nodes can run pods. Taints are applied to nodes, and tolerations are set on pods, allowing pods to tolerate the taints and be scheduled onto tainted nodes.

## How to Set Taints on Nodes

### Apply a Taint to a Node
To apply a taint to a node, use the following command:
```bash
kubectl taint nodes <node_name> <taint_key>=<taint_value>:<taint_effect>
```

### Example of Applying a Taint to a Node
For example:
```bash
kubectl taint nodes node1 key1=value1:NoSchedule
```

### Available Taint Effects and Explanations
- **NoSchedule**: Prevents new pods from being scheduled onto the node but allows already running pods to continue. New pods won't be scheduled unless they have a matching toleration.
- **PreferNoSchedule**: Similar to NoSchedule, but the scheduler tries to avoid placing pods on the node if possible.
- **NoExecute**: Evicts existing pods that do not tolerate the taint. Pods must have tolerations to remain on the node. This effect triggers pods' eviction if tolerations are removed or don't match the taint.

## How to Use Tolerations within a Pod

### Add Toleration to a Pod
To allow a pod to tolerate a taint, specify tolerations in the pod's YAML definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  tolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoSchedule"
```

### Available Toleration Types and Explanations
- **Exists**: Matches if the named key exists.
- **Equal**: Matches when the value of the key equals the given value.
- **Exists and Equal**: Combines both Exists and Equal to specify both key existence and value equality.

## Useful Commands for Taints and Tolerations

### List Taints on Nodes
```bash
kubectl describe node <node_name>
```

### List Pods with Tolerations
```bash
kubectl get pods -o=custom-columns=NAME:.metadata.name,TOLERATIONS:.spec.tolerations
```

### Describe Tolerations for a Pod
```bash
kubectl describe pod <pod_name> | grep -i tolerations
```