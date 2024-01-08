# Liveness probes

Kubernetes offers the capability to confirm the ongoing functionality of an application by setting up a liveness probe. You have the option to define a liveness probe for individual containers within a pod. Periodically, Kubernetes executes this probe to inquire whether the application remains operational. If the application fails to respond, generates an error, or delivers an unfavorable response, the container is marked as unhealthy and subsequently terminated. Depending on the restart policy in place, the container may then be restarted.

## Http probe

```yaml
    image: your-image
    livenessProbe:
      httpGet:
        path: /healthz   # Endpoint to check
        port: 8080       # Port to access the endpoint
      initialDelaySeconds: 15  # Delay before the first probe
      periodSeconds: 10        # Period between probes
```

## TCP Probe

```yaml
    image: your-image
    livenessProbe:
      tcpSocket:
        port: 8080       # Port to check the TCP connection
      initialDelaySeconds: 20  # Delay before the first probe
      periodSeconds: 15        # Period between probes
```

## Exec Probe

```yaml
    livenessProbe:
      exec:
        command:
          - cat
          - /app/health.txt   # Command to execute within the container
      initialDelaySeconds: 10  # Delay before the first probe
      periodSeconds: 20        # Period between probes
```

# Startup probes

The startup probe runs as the container starts. It's useful for handling slow application starts. Once the startup probe confirms success, Kubernetes switches to the liveness probe. The liveness probe is designed to swiftly spot when the application isn't working properly.

```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
```

TCP and Exec probes can be used as startup probes.

# Hooks

Kubernetes hooks are mechanisms that enable running custom actions at various points in the lifecycle of a resource, such as before or after specific events occur. They allow you to execute tasks or scripts to perform operations related to the deployment, scaling, or deletion of resources within Kubernetes.

## Types of Kubernetes Hooks

1. **Post-Start Hook:** The post-start lifecycle hook is invoked immediately after the container is created (async execution).
2. **Pre-Stop Hook:** Executes a command before a container is terminated.

## Post-Start Hook

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: post-start-hook-example
spec:
  containers:
  - name: app-container
    image: your-image
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo 'Post-start hook executed'"]
```

## Pre-Stop Hook

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pre-stop-hook-example
spec:
  containers:
  - name: app-container
    image: your-image
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "echo 'Pre-stop hook executed'"]
```

HttpGet hooks are available as well:
```yaml
lifecycle:
  postStart:
  httpGet:
    host: myservice.example.com
    port: 80
    path: /container-started
```