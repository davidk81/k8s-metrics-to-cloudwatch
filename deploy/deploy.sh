#!/bin/bash
set -e
BASEPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CICD_TOOLS=${CI_PROJECT_DIR}/.cicd-tools
source ${CICD_TOOLS}/bash_helpers.sh

BUILD_ENV=$1
export K8S_NAMESPACE="metrics-poller"
init_ci_pipeline_id
var_set_default CI_PROJECT_PATH_SLUG "threatservice-utils-k8s-infra"

ENVSUBST_VARS='$REGISTRY,$CI_PROJECT_PATH_SLUG,$CI_PIPELINE_ID,$ENV_SLUG,$POD_REPLICAS,$BACKEND_REPLICAS,$POD_PRIORITY,$CONTAINER_NAME,$FLUENTD_AWS_KEY,$FLUENTD_AWS_SECRET,$FLUENTD_AWS_REGION,$K8S_CLUSTER_NAME,$KOPS_AWS_KEY,$KOPS_AWS_SECRET,$K8S_CLUSTER_REGION,$KOPS_STATE_STORE,$K8S_NAMESPACE'
DEPLOY_YAML_LIST="$BASEPATH/metrics-poller.yaml"
${CICD_TOOLS}/deploy-k8s/k8s-deploy.sh ${BUILD_ENV} ${K8S_NAMESPACE} "${DEPLOY_YAML_LIST}" "${ENVSUBST_VARS}"
