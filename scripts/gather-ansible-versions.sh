#!/usr/bin/env bash
# Gather the versions the RUNNING Ansible install uses, and print values for envs/drroc4.env.
# Read-only (only `oc get`). v2: checks access up front, shows oc errors, discovers namespaces.
set -uo pipefail

command -v oc >/dev/null || { echo "ERROR: 'oc' not on PATH."; exit 1; }
if ! oc whoami >/dev/null 2>&1; then
  echo "ERROR: not logged in to the cluster in this shell. Run 'oc login ...' and retry."
  echo "(this is why a previous run showed all-blank values)"; exit 1
fi
echo "Logged in as: $(oc whoami)  server: $(oc whoami --show-server 2>/dev/null)"
CATALOG_NS="openshift-marketplace"
line(){ printf '%s\n' "------------------------------------------------------------"; }

echo; line; echo " OPERATOR CATALOG (master pin)"; line
echo -n "spec.image: "; oc get catalogsource ibm-operator-catalog -n "$CATALOG_NS" -o jsonpath='{.spec.image}'; echo
echo -n "resolved pod imageID (digest): "
oc get pod -n "$CATALOG_NS" -l olm.catalogSource=ibm-operator-catalog \
  -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'; echo

echo; line; echo " SUBSCRIPTIONS / CSVs (parity targets, ALL namespaces)"; line
oc get sub -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,CH:.spec.channel,CSV:.status.installedCSV \
  | grep -Ei 'NAMESPACE|ibm-mas|ibm-sls|manage|cert-manager|data-reporter|truststore|dro' || echo "(no matching subscriptions found)"

echo; line; echo " NAMESPACES + PRODUCT CR VERSIONS"; line
echo "mas core namespaces:"; oc get ns -o name | grep -oE 'mas-[a-z0-9]+-core' || true
for ns in $(oc get ns -o name | grep -oE 'mas-[a-z0-9]+-core'); do
  echo -n "  Suite in $ns: "; oc get suite -n "$ns" -o jsonpath='{.items[0].status.versions.reconciled}' 2>/dev/null; echo
done
echo "SLS licenseservice (all ns):"
oc get licenseservice -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,VER:.status.versions.reconciled,INIT:.status.initialized 2>/dev/null || true

echo; line; echo " >>> PASTE INTO envs/drroc4.env (use the Ansible instance's values) <<<"; line
echo "MAS_CHANNEL=<ibm-mas sub channel>"
echo "MAS_APP_CHANNEL=<ibm-mas-manage sub channel>"
echo "SLS_CHANNEL=<ibm-sls sub channel>"
echo "MAS_CATALOG_IMAGE=icr.io/cpopen/ibm-maximo-operator-catalog"
echo "MAS_CATALOG_VERSION=<the vX-YYMMDD-amd64 TAG from spec.image above>"
echo
echo "The INSTALLED CSV column is your exact parity target. After the fresh GitOps install,"
echo "re-run this and the drgitopsapp CSVs must match the drmasapp ones."
