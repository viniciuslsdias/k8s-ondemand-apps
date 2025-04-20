#!/bin/bash

# List of all deployments in the format deployment_name:namespace
ALL_DEPLOYMENTS=$(kubectl get deploy -A -o jsonpath="{range .items[*]}{.metadata.name}:{.metadata.namespace}{'\n'}{end}")
NAMESPACES_TO_EXCLUDE="kube-system cost-saver"
REPLICAS_COUNT=0

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
  fi
done