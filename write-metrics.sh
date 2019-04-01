#!/bin/sh
# tested on kubectl version 1.11.8

log() {
    echo -e "\033[1;${1}m${2}\033[m"
}

set -e

if [[ -z "$K8S_CLUSTER_NAME" || -z "$K8S_CLUSTER_REGION" ]]; then
    log 32 "K8S_CLUSTER_NAME / K8S_CLUSTER_REGION env variable must be defined"
    exit 1
fi

log 36 "$0 - Writing cluster metrics ($K8S_CLUSTER_NAME) to Cloudwatch - $(date)"

CW_NAMESPACE="K8S-Metrics"
export K8S_NAMESPACE_EXCLUDE=${K8S_NAMESPACE_EXCLUDE:=""}

export tmpfile=".metrics.json"
echo "[]" > $tmpfile

# master node list
export MASTER_NODES=$(kubectl get nodes --no-headers | grep master | awk '{ print $1}')

# master namespace list
export K8S_NAMESPACES=$(kubectl get namespaces --no-headers | awk '{ print $1}')

# Write node request metrics to CW
process_node_requests() {
    NODE_NAME=$1

    kubectl describe node $NODE_NAME > .temp

    CPU_REQUEST=$(cat .temp | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- | grep % | awk "{print \$3}" | sed 's/[^0-9]*//g' | awk "{print \$1}" | sed -sn '1p')
    MEM_REQUEST=$(cat .temp | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- | grep % | awk "{print \$3}" | sed 's/[^0-9]*//g' | awk "{print \$1}" | sed -sn '2p')
    CPU_LIMITS=$(cat .temp | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- | grep % | awk "{print \$5}" | sed 's/[^0-9]*//g' | awk "{print \$1}" | sed -sn '1p')
    MEM_LIMITS=$(cat .temp | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- | grep % | awk "{print \$5}" | sed 's/[^0-9]*//g' | awk "{print \$1}" | sed -sn '2p')

    # set node role (master/node)
    if grep -q $NODE_NAME <<<"$MASTER_NODES"; then
        NODE_ROLE=master
    else
        NODE_ROLE=node
    fi

    echo -e "$NODE_NAME \t cpu_requests: $CPU_REQUEST % \t mem_requests: $MEM_REQUEST % \t role: $NODE_ROLE"

    echo $(jq -r \
            --argjson CPU_REQUEST $CPU_REQUEST \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "cpu_requests",
        "Value": $CPU_REQUEST,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo $(jq -r \
            --argjson MEM_REQUEST $MEM_REQUEST \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "mem_requests",
        "Value": $MEM_REQUEST,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo -e "$NODE_NAME \t cpu_limits  : $CPU_LIMITS % \t mem_limits  : $MEM_LIMITS % \t role: $NODE_ROLE"

    echo $(jq -r \
            --argjson CPU_LIMITS $CPU_LIMITS \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "cpu_limits",
        "Value": $CPU_LIMITS,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo $(jq -r \
            --argjson MEM_LIMITS $MEM_LIMITS \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "mem_limits",
        "Value": $MEM_LIMITS,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile
}
export -f process_node_requests
log 33 "Reading node cpu & memory requests"
kubectl get nodes --no-headers | awk '{print $1}' | xargs -I {} sh -c 'process_node_requests {}'

# Write actual cpu / mem usage per node
process_top_nodes() {
    NODE_NAME=$1
    CPU_USAGE=$(echo $3 | sed 's/[^0-9]*//g')
    MEM_USAGE=$(echo $5 | sed 's/[^0-9]*//g')

    # set node role (master/node)
    if grep -q $NODE_NAME <<<"$MASTER_NODES"; then
        NODE_ROLE=master
    else
        NODE_ROLE=node
    fi

    echo -e "$NODE_NAME \t cpu_usage: $CPU_USAGE % \t mem_used_percent: $MEM_USAGE % \t role: $NODE_ROLE"

    echo $(jq -r \
            --argjson CPU_USAGE $CPU_USAGE \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "cpu_usage_percent",
        "Value": $CPU_USAGE,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo $(jq -r \
            --argjson MEM_USAGE $MEM_USAGE \
            --arg NODE_NAME $NODE_NAME \
            --arg NODE_ROLE $NODE_ROLE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "mem_used_percent",
        "Value": $MEM_USAGE,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "NodeName",
            "Value": $NODE_NAME
            },{
            "Name": "NodeRole",
            "Value": $NODE_ROLE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile
}
export -f process_top_nodes
log 33 "Reading node cpu & memory usage"
kubectl top nodes | sed -n '1!p' | xargs -I {} bash -c 'process_top_nodes {}'

# Write actual cpu / mem usage per node
process_top_pods() {
    NAMESPACE=$1

    # exit function if namespace is in exclude list
    if grep -q $NAMESPACE <<<"$K8S_NAMESPACE_EXCLUDE"; then
        return 0
    fi

    POD_NAME=$2
    CPU_USAGE=$(echo $3 | sed 's/[^0-9]*//g')
    CPU_PERCENT=$(jq -n $CPU_USAGE/10)
    MEM_USAGE=$(echo $4 | sed 's/[^0-9]*//g')
    echo -e "$NAMESPACE \t $POD_NAME \t cpu_usage_percent: $CPU_PERCENT % \t mem_used: $MEM_USAGE Mi"

    echo $(jq -r \
            --argjson CPU_PERCENT $CPU_PERCENT \
            --arg NAMESPACE "$NAMESPACE" \
            --arg POD_NAME "$POD_NAME" \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "cpu_usage_percent",
        "Value": $CPU_PERCENT,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "Namespace",
            "Value": $NAMESPACE
            },{
            "Name": "PodName",
            "Value": $POD_NAME
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo $(jq -r \
            --argjson MEM_USAGE $MEM_USAGE \
            --arg NAMESPACE "$NAMESPACE" \
            --arg POD_NAME "$POD_NAME" \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "mem_used",
        "Value": $MEM_USAGE,
        "Unit": "Megabytes",
        "Dimensions": [{
            "Name": "Namespace",
            "Value": $NAMESPACE
            },{
            "Name": "PodName",
            "Value": $POD_NAME
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile
}
export -f process_top_pods
log 33 "Reading pod cpu & memory usage"
kubectl top pods --all-namespaces | sed -n '1!p' > .top_pods
cat .top_pods | xargs -I {} bash -c 'process_top_pods {}'

# aggregating namespace resource usage
log 33 "Aggregating namespace cpu & memory usage"
for NAMESPACE in $K8S_NAMESPACES; do
    CPU_USAGE=$(cat .top_pods | grep -E "^$NAMESPACE\s" | awk '{ print $3; }' | sed 's/[^0-9]*//g' | awk '{ sum += $1 } END { print sum }')
    MEM_USAGE=$(cat .top_pods | grep -E "^$NAMESPACE\s" | awk '{ print $4; }' | sed 's/[^0-9]*//g' | awk '{ sum += $1 } END { print sum }')

    # skip if no value
    if [ -z $CPU_USAGE ] || [ -z $MEM_USAGE ]; then
        continue
    fi

    CPU_PERCENT=$(jq -n $CPU_USAGE/10)
    echo -e "$NAMESPACE \t cpu_usage: $CPU_PERCENT % \t mem_usage: $MEM_USAGE Mi"

    echo $(jq -r \
            --argjson CPU_PERCENT $CPU_PERCENT \
            --arg NAMESPACE $NAMESPACE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "cpu_usage_percent",
        "Value": $CPU_PERCENT,
        "Unit": "Percent",
        "Dimensions": [{
            "Name": "Namespace",
            "Value": $NAMESPACE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile

    echo $(jq -r \
            --argjson MEM_USAGE $MEM_USAGE \
            --arg NAMESPACE $NAMESPACE \
            --arg K8S_CLUSTER_NAME $K8S_CLUSTER_NAME \
        '.[. | length] |= . + {
        "MetricName": "mem_used",
        "Value": $MEM_USAGE,
        "Unit": "Megabytes",
        "Dimensions": [{
            "Name": "Namespace",
            "Value": $NAMESPACE
            },{
            "Name": "ClusterName",
            "Value": $K8S_CLUSTER_NAME
            }]
        }' $tmpfile) > $tmpfile
done

# split into 20 items per file
log 33 "Created metrics file, splitting into 20 items per file (aws cloudwatch put-metric-data limitation)"
echo $(cat $tmpfile | jq '_nwise(20)') > $tmpfile.1
awk '{gsub(/\] \[/,"]\n[")}1' $tmpfile.1 >  $tmpfile.2

# read metrics line by line and send to cloudwatch
log 33 "Sending metrics to Cloudwatch, region:$K8S_CLUSTER_REGION, namespace:$CW_NAMESPACE"
while IFS='' read -r line || [[ -n "$line" ]]; do
    printf ". "
    echo $line > $tmpfile.3
    aws cloudwatch put-metric-data --region $K8S_CLUSTER_REGION --namespace "$CW_NAMESPACE" --metric-data file://$tmpfile.3 || true
done < "$tmpfile.2"
printf "\n"

log 33 "Done"
exit 0
