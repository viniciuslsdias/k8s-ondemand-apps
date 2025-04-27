# From Always-On to On-Demand: Optimize Kubernetes Costs in Non-Production Environments

Most tech companies maintain a non-production environment for customers to integrate with their products via provided APIs. These environments are typically used during business hours on weekdays. Depending on the industry, they may go unused for days if there are no new customers integrating.

In addition to customer-facing environments, companies also maintain internal development environments. These are used by developers and QA teams to test and validate new features, perform load testing, and conduct other quality assurance tasks. Like the external non-production environments, these internal systems are usually active during business hours and may remain idle during off-hours or when not in use.

The goal of this material is to present a commonly used approach to reduce costs associated with idle environments running inside Kubernetes, and to explore ways to create optimized, on-demand environments.

## Scheduled Startup and Shutdown

A common and effective approach is to use Kubernetes CronJobs to schedule the startup and shutdown of applications during business hours on weekdays. This ensures that environments are only active when needed, reducing unnecessary resource usage.

It's important to note, however, that shutting down applications is only cost-effective when the worker nodes are configured with autoscaling. For example, in AWS EKS, solutions like Karpenter and Cluster Autoscaler can automatically scale down nodes when no workloads are running.

Let us take a closer look at how to set up a scheduled job that turns all applications on and off, excluding only the core components necessary for Kubernetes operation.

### Diving into the Scheduler

The scheduler relies on several components to function properly. All necessary resources such as the ServiceAccount, ClusterRole, ClusterRoleBinding, and others are defined in the manifests.yaml file. By simply applying this file, the CronJob and its dependencies will be set up and start working as expected. However, two parts of the code are particularly worth highlighting: the shell script and the CronJob definition itself.

A single shell script is used by both the startup and shutdown CronJobs. It includes a variable called `REPLICAS_COUNT`, which is set to zero during shutdown and to one during startup. The script then iterates over the `ALL_DEPLOYMENTS` list, which contains deployment names and their corresponding namespaces in the format `deployment_name:namespace`. Inside the loop, a function named `should_process` is called to determine whether each deployment should be updated. This function checks if the deployment's namespace is in the `NAMESPACES_TO_EXCLUDE` variable, which contains Kubernetes operational namespaces and other namespaces not desired to be updated. Deployments not excluded by this check have their replica count modified.

```bash
#!/bin/bash

# List of all deployments in the format deployment_name:namespace
ALL_DEPLOYMENTS=$(kubectl get deploy -A -o jsonpath="{range .items[*]}{.metadata.name}:{.metadata.namespace}{'\n'}{end}")
# NAMESPACES_TO_EXCLUDE="kube-system cost-saver"
# REPLICAS_COUNT=0

should_process() {
  local ns=$1
  for excluded in $NAMESPACES_TO_EXCLUDE; do
    if [[ "$excluded" == "$ns" ]]; then
      return 1 # 1 = false
    fi
  done
  return 0 # 0 = true
}

for deployment_namespace in $ALL_DEPLOYMENTS; do

  deployment=${deployment_namespace%%:*}
  namespace=${deployment_namespace#*:}

  if should_process $namespace ; then
    echo "kubectl scale deployment $deployment --replicas=$REPLICAS_COUNT -n $namespace"
    kubectl scale deployment $deployment --replicas=$REPLICAS_COUNT -n $namespace
    echo "" # Skip a line
  fi
done
```

In the CronJob manifest, a few key details are worth pointing out. The startup schedule is set for 11:00 UTC, Monday through Friday, which corresponds to 8:00 AM in Brasília (Brazil) time (UTC-3). The shutdown schedule is set for 21:00 UTC, or 6:00 PM in Brasília time. The RBAC configuration for the `cost-saver-sa` service account grants only the minimum permissions required for its purpose. The choice of the `bitnami/kubectl:1.32.3` container image was made because it includes the kubectl CLI. Additionally, the script is provided to the pod via a volume sourced from a ConfigMap. Finally, the two variables, `NAMESPACES_TO_EXCLUDE` and `REPLICAS_COUNT`, are passed into the CronJob based on the specific needs.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: shutdown
  namespace: cost-saver
spec:
  schedule: '0 21 * * 1-5' # At 21:00 UTC on every day-of-week from Monday through Friday. (18h UTC-3)
  jobTemplate:
    metadata:
      name: shutdown
    spec:
      ttlSecondsAfterFinished: 100
      template:
        metadata:
        spec:
          serviceAccount: cost-saver-sa
          containers:
          - image: bitnami/kubectl:1.32.3
            name: shutdown
            command: ["/bin/bash", "-c"]
            args: ["REPLICAS_COUNT=$REPLICAS_COUNT NAMESPACES_TO_EXCLUDE=$NAMESPACES_TO_EXCLUDE /tmp/script/scale_script.sh"]
            volumeMounts:
            - name: scale-script
              mountPath: /tmp/script
            env:
            - name: NAMESPACES_TO_EXCLUDE
              value: "kube-system cost-saver"
            - name: REPLICAS_COUNT
              value: "0"
          volumes:
          - name: scale-script
            configMap:
              name: scale-script
              defaultMode: 0777
          restartPolicy: OnFailure
```