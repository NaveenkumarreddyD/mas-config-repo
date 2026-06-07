# Fresh-start kit — drgitopsapp on drroc4, version-matched to Ansible (drmasapp)

This is your existing `mas-config-repo` with a version-alignment layer added. Nothing about the
config structure changed — only how versions are pinned, plus runbooks/scripts for a clean rebuild.

## Order of operations
1. **Gather Ansible versions:** `scripts/gather-ansible-versions.sh` → paste the printed block into `envs/drroc4.env`.
2. **Uninstall the current GitOps install:** follow `docs/uninstall-gitops.md` (leaves Ansible, Mongo, ibm-sls, platform-gitops intact).
3. **Render:** `./render.sh drroc4`, commit, push.
4. **Bring up fresh:** follow `docs/greenfield-bringup.md` (Vault seed → SLS license → manual SLS handoff via `scripts/capture-sls-registration.sh` → Core).
5. **Prove parity:** re-run the gather script against `drgitopsapp`; CSV versions must match `drmasapp`.

## What changed vs your current repo
- `envs/drroc4.env` — version section restructured; catalog can now be pinned by **digest** (the fix
  for the 3.9.1-vs-3.12.2 drift). See `docs/version-alignment.md`.
- Added `scripts/gather-ansible-versions.sh`, `scripts/capture-sls-registration.sh`.
- Added `docs/uninstall-gitops.md`, `docs/greenfield-bringup.md`, `docs/version-alignment.md`.

## Unchanged / out of scope here
- `platform-gitops` (Vault + AVP + account-root) — keep as-is; you re-point it at this repo.
- MongoDB Community — already running, shared; referenced not deployed.
- JDBC (Oracle) + Manage — stay deferred until Oracle details exist.

## Key facts baked in (from prior analysis)
- SLS is licensed from Vault `…/license#license_file` via the `ibm-sls-sls-entitlement` secret.
- The SLS→Core registration handoff is **manual under Vault** (IBM's auto-writer is AWS-Secrets-Manager-only);
  `run_sync_hooks: false` is intentional. `capture-sls-registration.sh` does that step.
- The operator catalog is the master version pin; pin by digest for reproducible parity with Ansible.

## Decisions confirmed from the Ansible env (this build matches them)
- **JDBC: non-SSL Oracle**, port 1521, `…/DEMAS`, user `maximo`. IBM charts are NOT modified —
  JDBC is removed from suite-configs and the non-SSL JdbcCfg comes from the locally-owned
  `extras/jdbc-external/` chart (deployed by `extras/jdbc-external-application.yaml`). No Oracle CA.
- **Catalog: v9-251010-amd64** (the newer of the two Ansible used) — carries SLS 3.12.x to match the
  running `ibm-sls` (3.12.2), MAS 8.11.x, and Manage 8.7.x from one catalog. Pin by digest to lock it.
  Manage's exact z-stream may differ from Ansible's (it pinned Manage to v9-240625); verify with gather.
- **DRO: kept** — the Ansible env sets DRO contact + storage, so DRO is in use. Do NOT remove `ibm-dro.yaml`.
- **cluster.nonshared: true — kept** — the cluster is dedicated long-term; both MAS instances run only
  during the PoC migration. No change needed.
