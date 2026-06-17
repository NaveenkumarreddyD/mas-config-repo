
merge-key: "${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}"

ibm_mas_masapp_configs:
  - mas_app_id: manage
    mas_app_namespace: mas-${INSTANCE_ID}-manage
    mas_app_ws_apiversion: apps.mas.ibm.com/v1
    mas_app_ws_kind: ManageWorkspace
    mas_workspace_id: ${WORKSPACE_ID}

    mas_manual_cert_mgmt: true
    run_sanity_test: false
    global_secrets:
      MXE_SECURITY_CRYPTO_KEY: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/manage-crypto#cryptoKey>"
      MXE_SECURITY_CRYPTOX_KEY: "<path:secret/data/${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/manage-crypto#cryptoxKey>"

    mas_appws_spec:
      bindings:
        jdbc: system
      components:
        base:
          version: ${MANAGE_COMPONENT_VERSION}
        utilities:
          version: ${MANAGE_COMPONENT_VERSION}
        spatial:
          version: ${MANAGE_COMPONENT_VERSION}
      settings:
        # AIO OFF so the explicit serverBundles below take effect. With AIO on (or with no
        # serverBundles), the operator collapses everything into a single 'all' server.
        aio:
          install: false
        db:
          dbSchema: ${DB_SCHEMA}
          encryptionSecret: ${WORKSPACE_ID}-manage-encryptionsecret
          maxinst:
            tableSpace: ${DB_TABLESPACE}
            indexSpace: ${DB_INDEXSPACE}
            demodata: false
            bypassUpgradeVersionCheck: false
        languages:
          baseLang: EN
          default: EN
        customizationList: []
        # CRITICAL nesting: serverTimezone, persistentVolumes and serverBundles MUST live under
        # settings.deployment. The ManageWorkspace CRD only reads them here; placed one level up
        # (directly under settings) they are SILENTLY DROPPED — the operator then defaults to AIO
        # (single 'all' server) and creates no PVCs (this is exactly the "no ui/cron/mea pods, no
        # PVCs" symptom). Matches the official ibm-mas-masapp-configs structure.
        deployment:
          autoGenerateEncryptionKeys: ${MANAGE_AUTO_GENERATE_ENCRYPTION_KEYS}
          defaultJMS: false
          serverTimezone: ${SERVER_TIMEZONE}
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
