merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

# External Oracle JDBC via the generic ibm-jdbc-config chart.
# NOTE: that chart hardcodes spec.config.sslEnabled: true and always emits a certificate alias,
# so jdbc_ca_pem is REQUIRED. Store the Oracle server/wallet CA at the jdbc-system#ca.crt Vault key
# and use a TLS (TCPS) Oracle listener in the jdbc_url.
ibm_mas_suite_configs:
  - mas_config_name: "${INSTANCE_ID}-jdbc-system"
    mas_config_chart: ibm-jdbc-config
    mas_config_scope: system
    mas_workspace_id:
    mas_application_id:
    mas_config_kind: "jdbccfgs"
    mas_config_api_version: "config.mas.ibm.com"
    use_postdelete_hooks: true

    jdbc_type: external
    jdbc_instance_name: "${INSTANCE_ID}-oracle"
    jdbc_instance_username: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/jdbc-system#username>"
    jdbc_instance_password: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/jdbc-system#password>"
    jdbc_connection_url: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/jdbc-system#jdbc_url>"
    mas_config_dir:
    jdbc_route:
    jdbc_ca_pem:
      crt: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/jdbc-system#ca.crt>"

    system_suite_jdbccfg_labels:
      mas.ibm.com/configScope: system
      mas.ibm.com/instanceId: "${INSTANCE_ID}"
    app_suite_jdbccfg_labels:
      mas.ibm.com/applicationId: "manage"
      mas.ibm.com/configScope: application
      mas.ibm.com/instanceId: "${INSTANCE_ID}"
    ws_suite_jdbccfg_labels:
      mas.ibm.com/configScope: workspace-application
      mas.ibm.com/instanceId: "${INSTANCE_ID}"
      mas.ibm.com/workspaceId: "${WORKSPACE_ID}"
    wsapp_suite_jdbccfg_labels:
      mas.ibm.com/applicationId: "manage"
      mas.ibm.com/configScope: workspace-application
      mas.ibm.com/instanceId: "${INSTANCE_ID}"
      mas.ibm.com/workspaceId: "${WORKSPACE_ID}"

  - mas_config_name: "${INSTANCE_ID}-sls-system"
    mas_config_chart: ibm-mas-sls-config
    mas_config_scope: system
    mas_workspace_id:
    mas_application_id:
    mas_config_kind: "slscfgs"
    mas_config_api_version: "config.mas.ibm.com"
    use_postdelete_hooks: true
    registration_key: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls#registration_key>"
    url: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls#url>"
    ca:
      crt: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls#ca.crt>"

  - mas_config_name: "${INSTANCE_ID}-mongo-system"
    mas_config_chart: ibm-mas-mongo-config
    mas_config_scope: system
    mas_workspace_id:
    mas_application_id:
    mas_config_kind: "mongocfgs"
    mas_config_api_version: "config.mas.ibm.com"
    use_postdelete_hooks: true
    username: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/mongo#username>"
    password: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/mongo#password>"
    config:
      hosts:
        - host: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/mongo#host>"
          port: 27017
      configDb: admin
      authMechanism: DEFAULT
      retryWrites: false
      credentials:
        secretName: "system-mongo-credentials"
      certificates:
        - alias: ca
          crt: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/mongo#ca.crt>"
