
merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

ibm_mas_masapp_configs:
  - mas_app_id: manage
    mas_app_namespace: mas-${INSTANCE_ID}-manage
    mas_app_ws_apiversion: apps.mas.ibm.com/v1
    mas_app_ws_kind: ManageWorkspace
    mas_workspace_id: ${WORKSPACE_ID}

    mas_manual_cert_mgmt: false
    run_sanity_test: false
    global_secrets:
      MXE_SECURITY_CRYPTO_KEY: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/manage-crypto#cryptoKey>"
      MXE_SECURITY_CRYPTOX_KEY: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/manage-crypto#cryptoxKey>"

    mas_appws_spec:
      bindings:
        jdbc: system
      components:
        base:
          version: latest
        utilities:
          version: latest
        spatial:
          version: latest
      settings:
        db:
          dbSchema: ${DB_SCHEMA}
          encryptionSecret: ${INSTANCE_ID}-${WORKSPACE_ID}-manage-crypto
          tableSpace: ${DB_TABLESPACE}
          indexSpace: ${DB_INDEXSPACE}
        deployment:
          autoGenerateEncryptionKeys: false
          defaultJMS: false
        languages:
          baseLang: EN
          default: EN
        serverTimezone: ${SERVER_TIMEZONE}
        customizationList: []
        persistentVolumes:
          - pvcName: jmsstore
            mountPath: /jmsstore
            size: 20Gi
            storageClassName: ${RWX_STORAGE_CLASS}
            accessModes:
              - ReadWriteMany
          - pvcName: globaldir
            mountPath: /globaldir
            size: 20Gi
            storageClassName: ${RWX_STORAGE_CLASS}
            accessModes:
              - ReadWriteMany
        serverBundles:
          - name: ui
            bundleType: ui
            isDefault: true
            replica: 1
            routeSubDomain: ui
          - name: cron
            bundleType: cron
            isDefault: false
            replica: 1
            routeSubDomain: cron
          - name: mea
            bundleType: mea
            isDefault: false
            replica: 1
            routeSubDomain: mea
          - name: jms
            bundleType: standalonejms
            isDefault: false
            replica: 1
            routeSubDomain: jms

    storage_class_definitions: {}
