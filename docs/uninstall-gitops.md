# Uninstall the current GitOps MAS install (drgitopsapp) — clean slate

Goal: remove everything the GitOps install created for **drgitopsapp**, without touching
shared cluster services that other instances still use.

Your sync policy uses `prune: false`, so ArgoCD will NOT auto-delete on its own — do it explicitly,
top-down, letting finalizers/post-delete hooks run.

## 0. Safety check — confirm what belongs to this GitOps instance
```bash
oc get applications -n openshift-gitops | grep drgitopsapp     # GitOps apps
oc get ns | grep -E 'mas-drgitopsapp|mongo-drgitops|ibm-software-central|cert-manager'
```
Touch only namespaces and Argo CD Applications for `drgitopsapp` unless you are intentionally
removing the dedicated Mongo namespace as part of a full reset.

## 1. Tear down from the top of the app tree
```bash
cd platform-gitops
./scripts/delete-mas-instance.sh --confirm ../mas-gitops-config/envs/drroc4.env
```
For a full reset of this instance's dedicated MongoDB, add `--include-mongo`.
Only add `--include-dro` when `ibm-software-central` is dedicated to this GitOps instance.

## 2. Clear stuck finalizers (only if a CR/namespace hangs Terminating)
```bash
./scripts/delete-mas-instance.sh --confirm ../mas-gitops-config/envs/drroc4.env
```

## 3. Delete the GitOps-only namespaces
```bash
./scripts/delete-mas-instance.sh --confirm --include-mongo ../mas-gitops-config/envs/drroc4.env
```

## 4. Do NOT remove shared/cluster-scoped pieces
Leave these unless you are rebuilding the whole platform:
- `ibm-operator-catalog` (shared catalog) — keep; the fresh install reuses it.
- cert-manager and DRO — cluster-scoped services when this is a shared cluster.
- Vault, AVP, and OpenShift GitOps bootstrap resources.
- The `platform-gitops` bootstrap (Vault, AVP, account-root Application) — keep; you re-point it.

## 5. Verify clean
```bash
oc get ns | grep mas-drgitopsapp        # should be empty
oc get applications -n openshift-gitops | grep drgitopsapp   # should be empty
```
Now follow `platform-gitops/DEPLOY.md`.
