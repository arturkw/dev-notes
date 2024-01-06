## 1. Difference between VM's and containers

Virtual Machines (VMs) are full-fledged virtualized environments that include an operating system, allowing multiple applications to run on a single physical machine. Containers, on the other hand, share the host OS kernel and package applications with their dependencies, enabling lightweight and efficient deployment.

## 2. K8s Control Plane

The Kubernetes Control Plane manages the cluster, comprising various components like the API Server, Controller Manager, Scheduler, and etcd.

## 3. K8s Workload Plane

The Workload Plane, managed by components like Kubelet and Container Runtime, handles the actual deployment and execution of applications within the Kubernetes cluster.

## 4. The Scheduler decides on which worker node each application instance should run.

This component of Kubernetes assigns pods (groups of containers) to nodes based on resource requirements, optimizing performance and resource utilization.

## 5. The etcd distributed datastore persists the objects you create through the API, since the API Server itself is stateless. The Server is the only component that talks to etcd.

Etcd serves as Kubernetes' distributed key-value store, maintaining the cluster's state and configurations, accessed exclusively by the API Server.

## 8. K8s API Server

The Kubernetes API Server exposes the RESTful Kubernetes API, allowing engineers and components to interact with the cluster by creating, modifying, or deleting objects.

## 9. Controllers

Controllers are Kubernetes components that manage the lifecycle of objects created through the API, ensuring desired states are maintained. Some controllers interact with external systems as well.

## 10. The Kubelet

Kubelet, an agent on each node, communicates with the API Server and manages applications running on the node. It reports statuses and handles deployment instructions via the API.

## 11. Container Runtime

The Container Runtime, such as Docker, executes applications in containers as instructed by the Kubelet, ensuring they run consistently within the cluster.

## 12. Kubernetes Service Proxy (Kube Proxy)

Kube Proxy handles network traffic and load balancing between applications within the cluster, although traffic no longer necessarily flows through it.


