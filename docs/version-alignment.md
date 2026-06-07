# Matching GitOps versions to the Ansible install (TAG-based)

## The catalog is the single master pin
Every MAS operator (Core, Manage, SLS, cert-manager, DRO, truststore-mgr) is installed by OLM
from the **IBM operator catalog** using a channel (e.g. `8.11.x`, `3.x`, `8.7.x`) + `Automatic`
install plan. With Automatic + a channel, OLM installs whatever CSV is the channel **head in the
catalog content**. So the version is determined by two things: the channel, and the catalog tag.

We pin the catalog by **tag** (`vX-YYMMDD-amd64`). IBM publishes these dated catalogs as fixed
snapshots — the same dated tag is meant to carry the same operator versions every time:
```
MAS_CATALOG_IMAGE=icr.io/cpopen/ibm-maximo-operator-catalog
MAS_CATALOG_VERSION=v9-240625-amd64      # ships Core 8.11.26 / Manage 8.7.24 / SLS 3.12.2
SLS_CHANNEL=3.x
```

## Step 1 — confirm the tag actually carries SLS 3.12.2
Don't trust the tag blindly; ask the catalog what its `3.x` head is **after** the CatalogSource syncs:
```
oc get packagemanifest ibm-sls -n openshift-marketplace \
  -o jsonpath='{range .status.channels[*]}{.name}={.currentCSV}{"\n"}{end}'
```
- If the `3.x` head is `ibm-sls.v3.12.2` -> the tag is correct; any wrong version on the cluster is
  the orphan-CSV problem in Step 2.
- If the `3.x` head is `3.9.x` -> this dated tag genuinely predates 3.12.2. Pick a **newer dated tag**
  (a later `v9-YYMMDD`) and re-check. Match it to whatever tag your Ansible `drmasapp` used —
  `scripts/gather-ansible-versions.sh` prints the running CatalogSource `spec.image` (the tag) and the
  installed CSVs, which are your parity targets.

## Step 2 — why GitOps SLS came up 3.9.1 (the real cause on this cluster)
The catalog head was 3.12.2, but the dedicated SLS namespace already had an older
`ibm-sls.v3.9.1` CSV (left over from a prior attempt). On a rolling `3.x` Subscription, OLM
**adopts the existing older CSV** instead of installing the catalog head — so it sticks at 3.9.1.

Fix (scoped to the instance SLS namespace ONLY, never the shared `ibm-sls`):
```
platform-gitops/scripts/preflight-sls.sh drgitopsapp        # shows head vs installed + the command
oc delete csv ibm-sls.v3.9.1 -n mas-drgitopsapp-sls          # OLM reinstalls the 3.x head -> 3.12.2
oc get csv -n mas-drgitopsapp-sls -w
```
`preflight-sls.sh <instanceId>` is read-only; add `--fix` to delete the stuck CSV for you.

## Optional — stop the tag re-resolving
OLM re-pulls the CatalogSource on `registryPoll` (default ~15m for tag-based sources). Dated tags are
fixed, so this is normally a no-op, but if you want zero chance of a re-pull changing content, widen or
drop the poll on the CatalogSource (trade-off: you then update the catalog only by changing the tag):
```
oc patch catalogsource ibm-operator-catalog -n openshift-marketplace --type merge \
  -p '{"spec":{"updateStrategy":{"registryPoll":{"interval":"720h"}}}}'
```

## Channels to confirm against Ansible
- `MAS_CHANNEL`     = `ibm-mas` sub channel in `mas-drmasapp-core`
- `MAS_APP_CHANNEL` = `ibm-mas-manage` sub channel in `mas-drmasapp-manage`
- `SLS_CHANNEL`     = `ibm-sls` sub channel

## Proving parity
`scripts/gather-ansible-versions.sh` prints the catalog tag, every Subscription's channel, and the
`INSTALLED CSV` per namespace. After the GitOps install, re-run it against `drgitopsapp` and the CSVs
must match `drmasapp` CSV-for-CSV.
