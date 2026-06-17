
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
      # All components 'latest': the operator resolves each to the version shipped in the pinned
      # catalog (the catalog tag is the real version control). base 'latest' = the catalog's Manage
      # version. NOTE: on a reused DB, a catalog bump will let base follow the new version and run a
      # schema upgrade (maxinst) — control that via the catalog tag + a DB backup, not a base pin.
      components:
        base:
          version: latest
        utilities:
          version: latest
        spatial:
          version: latest
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
          # Parameterized (NOT hardcoded false): a reused DB needs its ORIGINAL keys. For PROD set
          # MANAGE_AUTO_GENERATE_ENCRYPTION_KEYS=false in the env + provide the keys in Vault. For a
          # nonprod/fresh DB that already auto-generated keys, keep it true so they aren't invalidated.
          autoGenerateEncryptionKeys: ${MANAGE_AUTO_GENERATE_ENCRYPTION_KEYS}
          defaultJMS: false                    # JMS handled by the dedicated standalonejms bundle
          serverTimezone: ${SERVER_TIMEZONE}
          # Per-server-bundle sizing (applies to EACH bundle pod). Tune to load/node capacity.
          resources:
            serverBundles:
              requests: { cpu: "1", memory: "4Gi" }
              limits:   { cpu: "6", memory: "10Gi" }
          # MUST be under settings.deployment (the CRD only reads them here).
          persistentVolumes:
            - { pvcName: jmsstore,  mountPath: /jmsstore,  size: 20Gi,  storageClassName: ${RWX_STORAGE_CLASS}, accessModes: [ReadWriteMany] }
            - { pvcName: globaldir, mountPath: /globaldir, size: 20Gi,  storageClassName: ${RWX_STORAGE_CLASS}, accessModes: [ReadWriteMany] }
            - { pvcName: doclinks,  mountPath: /DOCLINKS,  size: 100Gi, storageClassName: ${RWX_STORAGE_CLASS}, accessModes: [ReadWriteMany] }
          serverBundles:
            - { name: ui,     bundleType: ui,            isDefault: true,  replica: 2, routeSubDomain: ui }     # HA + UI load
            - { name: cron,   bundleType: cron,          isDefault: false, replica: 1, routeSubDomain: cron }   # singleton scheduler
            - { name: mea,    bundleType: mea,           isDefault: false, replica: 2, routeSubDomain: mea }    # integration throughput
            - { name: report, bundleType: report,        isDefault: false, replica: 1, routeSubDomain: report }
            - { name: jms,    bundleType: standalonejms, isDefault: false, replica: 1, routeSubDomain: jms }    # singleton messaging engine

    storage_class_definitions: {}
