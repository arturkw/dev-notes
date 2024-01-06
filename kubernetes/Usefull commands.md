
To get documentation for resource:
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod --recursive
kubectl get ev
kubectl get ev -o wide
kubectl get ev --field-selector type=Warning

To get logs:
kubectl logs <podname>
kubectl logs <podname> -f
kubectl logs <podname> --timestamp=true
kubectl logs <podname> --since=2m
kubectl logs <podname> --since-time=2020-02-01T09:50:00Z

Copy file to/from container:
kubectl cp <podname:/file> <localfilename>
kubectl cp <localfilename> <podname:/targetdirectory>

Executing commands in running containers:
kubectl exec <podname> -- <command>

Run interactive shell in the container:
kubectl exec -it <podname> -- bash

Attach to a runing container (attach to standard input, output, errorstrem):
kubectl attach <podname>



