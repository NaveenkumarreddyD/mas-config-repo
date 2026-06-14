merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

# JDBC is intentionally NOT configured here. IBM's 130-ibm-jdbc-config chart hardcodes
# sslEnabled:true; our Oracle is non-SSL (TCP/1521). The non-SSL JdbcCfg is created by our
# own chart in platform-gitops/workloads/jdbc (deployed by the app-of-apps wave 40) so the
# IBM charts stay untouched. sls + bas + mongo are registered through suite-configs.
# NOTE: this instance runs its OWN dedicated SLS (base/instance/ibm-sls.yaml). The slscfg below
# points Core at it; the registration_key/url/ca come from THIS instance's LicenseService
# (namespace mas-${INSTANCE_ID}-sls) and are synced into Vault by
# platform-gitops/scripts/sync-runtime-registration.sh.
ibm_mas_suite_configs:
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

# BEGIN_OPTIONAL_BAS_CONFIG
  - mas_config_name: "${INSTANCE_ID}-bas-system"
    mas_config_chart: ibm-mas-bas-config
    mas_config_scope: system
    mas_workspace_id:
    mas_application_id:
    mas_config_kind: "bascfgs"
    mas_config_api_version: "config.mas.ibm.com"
    use_postdelete_hooks: true
    # BAS = DRO integration. Endpoint/token/CA are harvested from the shared DRO into Vault
    # into Vault by platform-gitops/scripts/sync-runtime-registration.sh (DRO + SLS handoff).
    dro_endpoint_url: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/dro#url>"
    dro_contact:
      email: "${DRO_CONTACT_EMAIL}"
      first_name: "${DRO_CONTACT_FIRSTNAME}"
      last_name: "${DRO_CONTACT_LASTNAME}"
    dro_api_token: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/dro#api_token>"
    dro_ca:
      crt: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/dro#ca.crt>"
# END_OPTIONAL_BAS_CONFIG

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
