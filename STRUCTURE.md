# mas-config-repo — structure (start here)

Declarative MAS configuration consumed by the platform-gitops `account-root` Application.
Kept SEPARATE from platform-gitops on purpose (MAS config vs platform/infra).

```
base/cluster/*.tpl     cluster-scoped MAS config templates (operator catalog, cluster base)
base/instance/*.tpl    instance-scoped templates (suite, suite-configs, manage install,
                       workspace, masapp-configs, dedicated SLS)
envs/<cluster>.env     ONE file per cluster — all variables (versions, IDs, namespaces,
                       SHARED_CLUSTER flag, DB/timezone/storage settings)
render.py              substitutes envs/<cluster>.env into base/*.tpl -> mas/<cluster>/...
                       (auto-skips cert-manager/DRO files on a shared cluster)
mas/<cluster>/...      rendered output that account-root globs and applies
scripts/, docs/
```

## Add a new cluster
`cp envs/<existing>.env envs/<cluster>.env`, edit IDs/versions, `python3 render.py <cluster>`,
commit. account-root (in platform-gitops) auto-discovers it.
