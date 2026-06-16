
merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

ibm_mas_suite:
  cert_manager_namespace: "cert-manager"
  ibm_entitlement_key: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/entitlement#image_pull_secret_b64>"
  domain: ${MAS_DOMAIN}
  mas_channel: "${MAS_CHANNEL}"
  icr_cp: "cp.icr.io/cp"
  icr_cp_open: "icr.io/cpopen"
  mas_install_plan: Automatic
  mas_operational_mode: ${OPERATIONAL_MODE}
  mas_feature_usage: ${MAS_FEATURE_USAGE}
  mas_deployment_progression: ${MAS_DEPLOYMENT_PROGRESSION}
  mas_usability_metrics: ${MAS_USABILITY_METRICS}
  mas_contract_performance: ${MAS_CONTRACT_PERFORMANCE}
  mas_manual_cert_mgmt: true
