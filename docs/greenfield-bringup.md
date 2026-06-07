# Greenfield bring-up — fresh GitOps install of drgitopsapp

Assumes: empty of any prior drgitopsapp install (see uninstall-gitops.md), MongoDB Community
already running and reachable, `platform-gitops` bootstrap (Vault + AVP + account-root) in place.

## 1. Align versions to Ansible (do this FIRST)
```bash
scripts/gather-ansible-versions.sh
```
Paste the printed channel + catalog-digest values into `envs/drroc4.env`, then:
```bash
./render.sh drroc4
git add -A && git commit -m "drgitopsapp: align versions to drmasapp (Ansible)" && git push
```
See `docs/version-alignment.md` for why the catalog digest matters.

## 2. Seed Vault
```bash
bash vault/drroc4-load-secrets.sh     # entitlement key, license.dat, mongo, sls-mongo, jdbc, crypto
```
Leave `secret/mas/drroc4/drgitopsapp/sls#{url,registration_key,ca.crt}` EMPTY for now —
SLS generates those at runtime (step 5).

## 3. Let GitOps reconcile cluster-base + SLS
Sync the account-root; cluster-base (catalog/cert-manager/DRO) and the instance SLS deploy.
SLS reads the license from Vault via the `ibm-sls-sls-entitlement` secret.

## 4. Wait for SLS to license itself
```bash
oc get licenseservice sls -n mas-drgitopsapp-sls
# INITIALIZED must read 'Initialized', NOT 'MissingConfiguration'.
```
If `MissingConfiguration`: the license didn't apply. Check the entitlement secret content matches
the known-good Ansible one:
```bash
oc get secret ibm-sls-sls-entitlement -n mas-drgitopsapp-sls -o jsonpath='{.data.entitlement}' | base64 -d | head -c 80; echo
oc get secret ibm-sls-sls-entitlement -n ibm-sls               -o jsonpath='{.data.entitlement}' | base64 -d | head -c 80; echo
```
Fix the Vault `license#license_file` content/format to match, re-sync.

## 5. Hand SLS registration to MAS Core (manual under Vault)
```bash
scripts/capture-sls-registration.sh           # reads SLS runtime values -> writes Vault sls#*
argocd app sync drgitopsapp-sls-system.drroc4  # SlsCfg now resolves
```

## 6. Bring up Core, then defer/Manage
```bash
argocd app sync mongo... sls... suite...        # Core: Mongo + SLS + Suite
oc get suite -n mas-drgitopsapp-core
```
JDBC (Oracle) + Manage stay deferred until Oracle details exist.

## 7. Verify parity with Ansible
```bash
ANSIBLE_INSTANCE_ID=drgitopsapp SLS_NS=mas-drgitopsapp-sls scripts/gather-ansible-versions.sh
```
The INSTALLED CSV versions must match drmasapp's. If not, see version-alignment.md.

## Oracle JDBC (non-SSL, matches Ansible) — no IBM chart changes
IBM's 130-ibm-jdbc-config chart forces sslEnabled:true, so JDBC is NOT routed through suite-configs.
Instead, the non-SSL JdbcCfg comes from the locally-owned chart `extras/jdbc-external/`.

1. Load the Oracle creds (no CA — SSL is off):
   ```bash
   export JDBC_USERNAME=maximo
   export JDBC_PASSWORD=maximo
   export JDBC_URL='jdbc:oracle:thin:@//stl-dmasdb-21.lac1.biz:1521/DEMAS'
   bash vault/drroc4-load-secrets.sh   # writes secret/mas/drroc4/drgitopsapp/jdbc-system (user/pass/url)
   ```
2. Register the Application (one of):
   - set `repoURL` in `extras/jdbc-external-application.yaml` and `oc apply -f` it, OR
   - drop that manifest into `platform-gitops` app-of-apps templates.
3. It renders a system-scoped JdbcCfg with `sslEnabled: false` and no certificates — identical to the
   Ansible install. MAS adopts it by label; Manage's `bindings.jdbc: system` binds to it.

## cert-manager toggle
- **Empty/fresh cluster:** leave `redhat-cert-manager.yaml` in place (it renders by default) so GitOps
  installs cert-manager. This is the case this kit is built for.
- **Current shared cluster (PoC alongside Ansible):** Ansible already installed cert-manager cluster-wide,
  so delete the rendered `mas/drroc4/redhat-cert-manager.yaml` before committing (and re-add it for the
  real fresh build). cert-manager is cluster-scoped; two installs would collide.

## Who populates which Vault path (all scripts live in platform-gitops/scripts)
- `load-secrets.sh envs/drroc4.env` — entitlement, license, superuser, manage-crypto, JDBC (non-SSL,
  no CA), and DERIVES mongo + sls-mongo from the `mongoce` namespace (single `mas-mongo-ce-svc` host).
- `harvest-sls-registration.sh envs/drroc4.env` — `sls` registration_key/url/ca after SLS is Ready.
- `sync-mongo-ca.sh` — re-sync the Mongo CA after a Mongo redeploy / CA rotation.

JDBC needs no manual app: the `40-ibm-mas-jdbc-external` app-of-apps entry deploys it from
`extras/jdbc-external`. Toggle TCPS via `jdbcExternal.sslEnabled` in platform-gitops values.


## SLS model — SHARED ibm-sls (not a dedicated SLS)
This instance does NOT install its own SLS. Like demasapp/drmasapp it registers against the shared
`ibm-sls` (licensed AADD01F580DF). `harvest-sls-registration.sh` is run with `SLS_NS=ibm-sls`.
(`sls-mongo` Vault keys are vestigial when using shared SLS and can be ignored.)

## BAS / DRO
`bas-system` is now in suite-configs and creates a BasCfg from the shared DRO. Run
`harvest-dro-registration.sh` once to put the DRO url/api_token/ca into Vault, then sync bas-system.
