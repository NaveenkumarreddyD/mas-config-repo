merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}"

account:
  id: ${ACCOUNT_ID}

region:
  id: ${REGION_ID}

cluster:
  id: ${CLUSTER_ID}
  url: ${CLUSTER_URL}
  nonshared: true

custom_labels:
  environment: ${CLUSTER_ID}
  platform: openshift
  gitops-owner: devops
