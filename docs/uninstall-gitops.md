# Uninstall the current GitOps MAS install (drgitopsapp) — clean slate

Goal: remove everything the GitOps install created for **drgitopsapp**, WITHOUT touching
the Ansible install (**drmasapp**), the shared MongoDB Community, or the shared `ibm-sls`.

Your sync policy uses `prune: false`, so ArgoCD will NOT auto-delete on its own — do it explicitly,
top-down, letting finalizers/post-delete hooks run.

## 0. Safety check — confirm what belongs to GitOps vs Ansible
```bash
oc get applications -n openshift-gitops | grep drgitopsapp     # GitOps apps
oc get ns | grep -E 'mas-drgitopsapp|mongoce|ibm-sls|mas-drmasapp'
```
Touch only `mas-drgitopsapp-*`. Leave `mas-drmasapp-*`, `mongoce`, and `ibm-sls` alone.

## 1. Tear down from the top of the app tree
```bash
# instance config + apps first (let post-delete hooks remove the MAS CRs cleanly)
for app in $(oc get applications -n openshift-gitops -o name | grep drgitopsapp); do
  argocd app delete "${app#application.argoproj.io/}" --cascade --yes
done
# then the account/cluster/instance root apps
argocd app delete ibm-mas-account-root --cascade --yes 2>/dev/null || true
```
Wait for the `mas-drgitopsapp-core` / `-manage` / `-sls` CRs (Suite, ManageApp/Workspace,
JdbcCfg/SlsCfg/MongoCfg, LicenseService) to be gone before deleting namespaces.

## 2. Clear stuck finalizers (only if a CR/namespace hangs Terminating)
```bash
oc get suite,manageapp,manageworkspace,jdbccfg,slscfg,mongocfg -n mas-drgitopsapp-core 2>/dev/null
# if one is stuck:
oc patch <kind>/<name> -n mas-drgitopsapp-core --type=merge -p '{"metadata":{"finalizers":[]}}'
```

## 3. Delete the GitOps-only namespaces
```bash
oc delete ns mas-drgitopsapp-core mas-drgitopsapp-manage mas-drgitopsapp-sls --wait=false
```

## 4. Do NOT remove shared/cluster-scoped pieces
Leave these — Ansible/`drmasapp` and the platform need them:
- `ibm-operator-catalog` (shared catalog) — keep; the fresh install reuses it.
- cert-manager, DRO operators — cluster-scoped, shared.
- MongoDB Community (`mongoce`) and `ibm-sls` — shared dependencies.
- The `platform-gitops` bootstrap (Vault, AVP, account-root Application) — keep; you re-point it.

## 5. Verify clean
```bash
oc get ns | grep mas-drgitopsapp        # should be empty
oc get applications -n openshift-gitops | grep drgitopsapp   # should be empty
```
Now follow `docs/greenfield-bringup.md`.
