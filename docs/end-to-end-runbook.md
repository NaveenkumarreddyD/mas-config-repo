# End-to-end runbook — fresh GitOps install of MAS `drgitopsapp` on `drroc4`

Two repos, clean responsibilities:
- **platform-gitops** — hub bootstrap (ArgoCD app-of-apps: Vault, AVP, account-root, jdbc-external) +
  all Vault secret tooling under `scripts/`.
- **mas-config-repo** (`mas-gitops-config`) — declarative MAS config the account-root generates from.

Identifiers: account `mas`, cluster `drroc4`, instance `drgitopsapp`, workspace `drgitopswks`.
Vault is HashiCorp KV v2 at `secret/`; ArgoCD resolves `<path:...>` via `argocd-vault-plugin-helm`.

**Mental model.** After the account-root is applied, ArgoCD generates and syncs everything in
sync-wave order (catalog → cert-manager/DRO → cluster-base → Suite → SLS → configs → JDBC → Manage).
You step in only at the marked points: **[RUN]**, **[WAIT]**, **[ONE-TIME]**. **[AUTO]** = no action.
The one runtime handoff is SLS registration (SLS mints its key at runtime and IBM's auto-writer only
targets AWS Secrets Manager, so under Vault you capture it by hand once).

---

## Phase 0 — Prerequisites (one-time per cluster)
0.1 **[WAIT]** `oc login` as cluster-admin; `oc whoami` works.
0.2 **[ONE-TIME]** OpenShift GitOps (ArgoCD) operator + instance running.
0.3 **[ONE-TIME]** From `platform-gitops`: apply the AVP sidecar patch to the ArgoCD CR, the GitLab CA
    configmap (`bootstrap/00`), repo-creds, and run `vault-auth/setup-vault-auth.sh` so the
    `mas-gitops` k8s role + policy exist and the repo-server SA can read `secret/mas/*`.
0.4 **[WAIT]** `isilon` StorageClass exists; Vault will be installed by the app-of-apps (Phase 4).
0.5 **Scope decision** — empty cluster (GitOps installs cert-manager + DRO) vs shared PoC cluster
    (Ansible already installed them → drop the two files in Step 1.3).

## Phase 1 — Prepare `mas-config-repo`
1.1 **[RUN]** Confirm `envs/drroc4.env` (digest-pinned: MAS 8.11.26 / Manage 8.7.24 / SLS 3.12.2).
1.2 **[RUN]** `./render.sh drroc4`  → writes `mas/drroc4/...`.
1.3 **[RUN]** Shared PoC cluster only: `rm mas/drroc4/redhat-cert-manager.yaml mas/drroc4/ibm-dro.yaml`.
1.4 **[RUN]** Commit & push `mas-config-repo`.

## Phase 2 — Load secrets into Vault (from platform-gitops)
2.1 **[RUN]** Generates superuser/crypto + the **dedicated Mongo** admin & slsmongo passwords (once),
    writes non-SSL JDBC, and sets `mongo#host` to the new dedicated service. (Mongo/SLS CA come later.)
```bash
export VAULT_TOKEN=...
export IBM_ENTITLEMENT_KEY=...  MAS_LICENSE_FILE=/path/license.dat  MAS_LICENSE_ID=AADD01F580DF
export JDBC_USERNAME=maximo  JDBC_PASSWORD=maximo
export JDBC_URL='jdbc:oracle:thin:@//stl-dmasdb-21.lac1.biz:1521/DEMAS'
./scripts/load-secrets.sh <path>/mas-config-repo/envs/drroc4.env
```
2.2 **[RUN]** `./scripts/preflight-vault.sh <env>` — mongo/sls CA WARNs are expected until Phase 5.

## Phase 3 — Point platform-gitops at the repos (one-time)
3.1 **[ONE-TIME]** In `values/values-management.yaml`: `generator.repo_url`→mas-config-repo,
    `source`→ibm-mas-gitops mirror (`8.0.0`), and the `jdbcExternal` block
    (`clusterId: drroc4`, `instanceId: drgitopsapp`, `sslEnabled: false`).
3.2 **[ONE-TIME]** Commit & push `platform-gitops`. Versions live only in `mas-config-repo`.

## Phase 4 — Bootstrap
4.1 **[RUN]** `oc apply -f bootstrap/02-platform-app-of-apps.yaml` → installs Vault, AVP, account-root,
    and the jdbc-external app.
4.2 **[AUTO]** ArgoCD generates cluster + instance Applications from `mas-config-repo`.

## Phase 5 — Guided sync (mostly [AUTO], one checkpoint)
5.1 **[AUTO/WAIT]** Catalog syncs first — verify the pinned digest:
```bash
oc get catalogsource ibm-operator-catalog -n openshift-marketplace -o jsonpath='{.spec.image}{"\n"}'
# ...@sha256:e74f646327e728aa523199e9dfb2e95efb67385755c3ac9f0763ab6563e63843
```
5.2 **[AUTO]** cert-manager + DRO (if kept), then cluster-base.
5.2a **[AUTO/WAIT]** Dedicated Mongo: operator (wave 24) + replica set `drgitopsapp-mongo` (wave 26)
     come up in `mongo-drgitops`. Watch: `oc get mongodbcommunity -n mongo-drgitops` until Running.
5.2b **[RUN] — CHECKPOINT: Mongo CA** (once Mongo is Ready) — copies the cert-manager CA into Vault:
```bash
./scripts/sync-mongo-ca.sh <path>/mas-config-repo/envs/drroc4.env
```
5.3 **[AUTO/WAIT]** Instance-base + Suite (Core) + **dedicated SLS**. `base/instance/ibm-sls.yaml`
    drives IBM's `100-ibm-sls` app: the `ibm-sls` operator + a `LicenseService` named `sls` in
    `mas-drgitopsapp-sls`, using the Vault license (`license#license_file`) and THIS instance's
    dedicated Mongo (`slsmongo` user). Wait for it to initialize:
```bash
oc get licenseservice sls -n mas-drgitopsapp-sls -o jsonpath='{.status.initialized}{" "}{.status.versions.reconciled}{"\n"}'
# entitlement sanity (must show INCREMENT/FEATURE, not just SERVER/VENDOR):
../platform-gitops/scripts/preflight-vault.sh envs/drroc4.env
```
5.5 **[RUN] — CHECKPOINT: SLS handoff** (from platform-gitops; harvest THIS instance's own SLS):
```bash
SLS_NS=mas-drgitopsapp-sls ./scripts/harvest-sls-registration.sh envs/drroc4.env
oc annotate application drgitopsapp-sls-system.drroc4 -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```
5.6 **[AUTO]** Once `mongo#ca.crt` is present (5.2b), mongo-system + sls-system reconcile; **jdbc-system**
    is deployed by the 40- app-of-apps entry (no manual step); then masapp-configs → Manage → workspaces.
5.7 **[WAIT]** `oc get manageworkspace -n mas-drgitopsapp-manage` and Manage pods Ready.

## Phase 6 — Verify parity
6.1 **[RUN]** `mas-config-repo/scripts/gather-ansible-versions.sh` and compare to `drmasapp`.
6.2 **[VERIFY]** Core 8.11.26, Manage 8.7.24, SLS 3.12.2, cert-manager v1.19.0, DRO v2.24.4.

## Phase 7 — Day-2
- **TCPS:** export `JDBC_CA_CRT` + a TCPS descriptor URL, re-run `load-secrets.sh`, set
  `jdbcExternal.sslEnabled: true` in platform-gitops values, sync. See `extras/jdbc-external/README.md`.
- **Decommission Ansible `drmasapp`** once GitOps is fully green.
- **Teardown:** `docs/uninstall-gitops.md`.

## One-screen human-run sequence
```bash
# mas-config-repo
./render.sh drroc4
# (shared cluster) rm mas/drroc4/redhat-cert-manager.yaml mas/drroc4/ibm-dro.yaml
git add -A && git commit -m "drgitopsapp fresh start" && git push

# platform-gitops (secrets + bootstrap)
./scripts/load-secrets.sh   <path>/mas-config-repo/envs/drroc4.env
./scripts/preflight-vault.sh <path>/mas-config-repo/envs/drroc4.env
oc apply -f bootstrap/02-platform-app-of-apps.yaml

# after the dedicated Mongo is Ready
./scripts/sync-mongo-ca.sh <path>/mas-config-repo/envs/drroc4.env
# SLS (own, in mas-drgitopsapp-sls) + DRO/BAS handoffs
SLS_NS=mas-drgitopsapp-sls ./scripts/harvest-sls-registration.sh <path>/mas-config-repo/envs/drroc4.env
./scripts/harvest-dro-registration.sh <path>/mas-config-repo/envs/drroc4.env

# verify
<path>/mas-config-repo/scripts/gather-ansible-versions.sh
```
