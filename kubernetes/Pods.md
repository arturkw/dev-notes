# Kubernetes Pods

## Introduction
Pods are the smallest deployable units in Kubernetes, representing one or more containers that share resources. This document provides essential commands and sample configurations to work with pods.

Since you shouldn’t run multiple processes in a single container, it’s evident you need
another higher-level construct that allows you to run related processes together even when
divided into multiple containers. These processes must be able to communicate with each
other like processes in a normal computer. And that is why pods were introduced.

## Sample Configurations

### Pod Definition (pod.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
spec:
  containers:
  - name: sample-container
    image: nginx:latest
    ports:
    - containerPort: 80
```

This YAML configuration defines a pod named `sample-pod` with an Nginx container running on port 80.

### Pod with Environment Variables (env-pod.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: env-container
    image: myapp:latest
    env:
    - name: DB_HOST
      value: "mysql-service"
    - name: DB_PORT
      value: "3306"
```

This YAML configuration demonstrates a pod named `env-pod` with a container that sets environment variables for connecting to a MySQL service.

## Init containers

A pod manifest can specify a list of containers to run when the pod starts and before the
pod’s normal containers are started. These containers are intended to initialize the pod and
are appropriately called init containers. 
```yaml
apiVersion: v1
kind: Pod
metadata:
	name: kiada-init
spec:
  initContainers:
    - name: init-demo
      image: luksa/init-demo:0.1
    - name: network-check
      image: luksa/network-connectivity-checker:0.1
  containers:
```


## Docker entrypoint and Kubernetes command

In Docker, the `ENTRYPOINT` and `CMD` directives serve distinct roles in defining container execution behavior. The `ENTRYPOINT` specifies the command to run when the container starts, serving as the fundamental executable for the container. Conversely, `CMD` specifies default arguments for the `ENTRYPOINT` or sets the default command when the `ENTRYPOINT` is not specified.

In Kubernetes, the command for a pod is defined within the pod's specification. This command instructs the container's entry point on what to execute when the pod starts. It can be altered at runtime but defaults to the command specified in the pod configuration.

Understanding these differences is crucial for configuring container behaviors both at the Docker level and within the Kubernetes ecosystem, ensuring effective container orchestration.

### Sample Dockerfile

```Dockerfile
FROM ubuntu
COPY script.sh /script.sh
ENTRYPOINT ["/script.sh"]
CMD ["arg1", "arg2"]
```

This Dockerfile uses an Ubuntu base image, copies a script named `script.sh` into the container, and sets it as the `ENTRYPOINT`. The `CMD` directive provides default arguments to the `ENTRYPOINT` script.

### Sample Kubernetes Pod YAML Configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
spec:
  containers:
  - name: my-container
    image: my-image:latest
    command: ["/bin/bash"]
    args: ["-c", "echo Hello Kubernetes!"]
```

This YAML defines a Kubernetes pod named `sample-pod` with a single container. The `command` field specifies the command to run, and the `args` field provides arguments to the command.

### Pod Phases

In any moment of the pod's lide, it's in one of the five phases: Pending, Running, Succeded, Failed, Unknown

### Restart Policy

| Restart Policy | Description |
| ---- | ---- |
| Always | Container is restarted regardless of the exit code the process terminated with. |
| OnFailure | Container is restarted only if the process terminates with a non-zero exit code. |
| Never | Container is never restarted |

## Useful Commands

1. **Create a Pod from YAML file**:
   ```bash
   kubectl create -f <pod.yaml>
   ```

2. **List Pods**:
   ```bash
   kubectl get pods
   ```

3. **List Pods with Additional Details**:
   ```bash
   kubectl get pods -o wide
   ```

4. **List Pods in All Namespaces**:
   ```bash
   kubectl get pods --all-namespaces
   ```

5. **Describe a Pod**:
   ```bash
   kubectl describe pod <pod_name>
   ```

6. **Delete a Pod**:
   ```bash
   kubectl delete pod <pod_name>
   ```

7. **Get Logs from a Pod**:
   ```bash
   kubectl logs <pod_name>
   ```

8. **Tail Logs from a Pod**:
   ```bash
   kubectl logs -f <pod_name>
   ```

9. **Execute Command in a Pod**:
   ```bash
   kubectl exec <pod_name> -- <command>
   ```

10. **Execute Command Interactively in a Pod**:
    ```bash
    kubectl exec -it <pod_name> -- <command>
    ```

11. **Copy Files to/from Pod**:
    ```bash
    kubectl cp <local_path> <pod_name>:<pod_path>
    kubectl cp <pod_name>:<pod_path> <local_path>
    ```

12. **Port Forwarding to a Pod**:
    ```bash
    kubectl port-forward <pod_name> <local_port>:<pod_port>
    ```

13. **Get Pod YAML Definition**:
    ```bash
    kubectl get pod <pod_name> -o yaml
    ```

14. **Edit a Pod**:
    ```bash
    kubectl edit pod <pod_name>
    ```

15. **Check Events for a Pod**:
    ```bash
    kubectl get events --field-selector involvedObject.name=<pod_name>
    ```

16. **Apply Changes to a Pod**:
    ```bash
    kubectl apply -f <updated_pod.yaml>
    ```

17. **Watch Changes in a Pod**:
    ```bash
    kubectl get pod <pod_name> --watch
    ```

18. **Create a Pod with Labels**:
    ```bash
    kubectl create -f <pod_with_labels.yaml>
    ```

19. **Filter Pods by Label Selector**:
    ```bash
    kubectl get pods -l <label_key>=<label_value>
    ```

20. **Get Resource Utilization for a Pod**:
    ```bash
    kubectl top pod <pod_name>
    ```

21. **View Detailed Status of a Pod**:
    ```bash
    kubectl get pod <pod_name> -o json | jq '.status'
    ```

22. **Check Pod Security Context**:
    ```bash
    kubectl get pod <pod_name> -o=jsonpath='{.spec.securityContext}'
    ```

23. **Get Pod IP Address**:
    ```bash
    kubectl get pod <pod_name> -o=jsonpath='{.status.podIP}'
    ```

24. **Check Pod DNS Information**:
    ```bash
    kubectl exec <pod_name> -- nslookup <domain_name>
    ```

25. **Delete All Pods in Namespace**:
    ```bash
    kubectl delete pods --all -n <namespace>
    ```
## Related Topics
[[Pods]] [[Config Maps]] [[Secrets]] [[Probes and hooks]] [[Security Context]] [[Service Account]] [[Taints And Tolerations]]
