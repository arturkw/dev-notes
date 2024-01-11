# Kubernetes NodePort Service

In Kubernetes, a NodePort service is a type of service that exposes an application outside the cluster by mapping a specific port on each node to a port on the service. This makes the service accessible externally, allowing external traffic to reach the pods running in the cluster.

## Key Characteristics

- **External Access:** NodePort services make applications accessible from outside the cluster by assigning a static port on each node.

- **Port Mapping:** Traffic to the assigned node port is forwarded to the service, which in turn load-balances the requests to the pods.

- **ClusterIP Inclusion:** NodePort services automatically receive a ClusterIP address, making them accessible internally as well.

## Creating a NodePort Service

To create a NodePort service, define a YAML resource manifest. Here's an example:

**`nodeport-service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nodeport-service
spec:
  selector:
    app: my-app   # Match labels with the pods you want to expose
  ports:
    - protocol: TCP
      port: 80     # Port on the service
      targetPort: 8080   # Port on the pods
  type: NodePort   # Service type is NodePort
```

**Explanation:**

- `metadata.name`: Specify a name for your service.

- `spec.selector`: Define label selectors to match the pods that should be part of the service.

- `spec.ports`: Specify the ports for the service. `port` is the port on the service itself, and `targetPort` is the port on the pods.

- `type: NodePort`: This line explicitly sets the service type to NodePort.

## Applying the Resource

Apply the service resource using `kubectl apply -f nodeport-service.yaml`.

```bash
kubectl apply -f nodeport-service.yaml
```

This will create a NodePort service named `my-nodeport-service` that exposes pods labeled with `app: my-app` on port 80.

## Accessing the Service

You can access the NodePort service externally by using any node's IP address and the assigned node port. For example, if your cluster node's IP is `192.168.1.100`, and the assigned node port is `31000`, you can access the service at `http://192.168.1.100:31000`.