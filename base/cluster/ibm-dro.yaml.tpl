
merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}"

ibm_dro:
  dro_namespace: ${DRO_NAMESPACE}
  ibm_entitlement_key: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/entitlement#image_pull_secret_b64>"
  contactEmail: "${DRO_CONTACT_EMAIL}"
  contactFirstName: "${DRO_CONTACT_FIRSTNAME}"
  contactLastName: "${DRO_CONTACT_LASTNAME}"
  dro_install_plan: Automatic
  imo_install_plan: Automatic
  run_sync_hooks: false
  # dro_cmm_setup intentionally omitted: the cluster-root generator emits this value QUOTED,
  # so a literal `false` becomes the string "false", which is TRUTHY in the chart's
  # {{- if .Values.dro_cmm_setup }} (11-dro-cmm_DataReporterConfig.yaml) and then nil-pointers
  # on .dro_cmm.auth_url. Omitting it renders dro_cmm_setup: "" (falsy) so CMM templates are skipped.
sm:
  aws_access_key_id: ""
  aws_secret_access_key: ""
