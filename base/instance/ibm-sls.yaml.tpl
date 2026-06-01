merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

ibm_sls:
  sls_channel: ${SLS_CHANNEL}
  sls_entitlement_file: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/license#license_file>"
  ibm_entitlement_key: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/entitlement#image_pull_secret_b64>"
  sls_install_plan: Automatic
  icr_cp_open: "icr.io/cpopen"
  run_sync_hooks: false

  mongodb_provider: "community"
  user_action: "add"
  sls_mongo_username: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls-mongo#username>"
  sls_mongo_password: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls-mongo#password>"
  sls_mongo_secret_name: sls-mongo-credentials
  mongo_spec:
    authMechanism: DEFAULT
    configDb: admin
    secretName: sls-mongo-credentials
    retryWrites: false
    nodes:
      - host: ${SLS_MONGO_HOST}
        port: 27017
    certificates:
      - alias: ca
        crt: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls-mongo#ca.crt>"
