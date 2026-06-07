
# config-repo deployment notes

The final MAS GitOps config must exist under:

```text
<ACCOUNT_ID>/<CLUSTER_ID>/<INSTANCE_ID>/
```

For this package, generated output is:

```text
mas/drroc4/drgitopsapp/
mas/roc4/gitopsapp/
```

Update environment files first:

```bash
vi envs/drroc4.env
vi envs/roc4.env
```

Render:

```bash
./render.sh --all
```

Validate generated files:

```bash
find mas -type f | sort
grep -Rni "CHANGE_ME" mas vault
python3 - <<'PY'
import pathlib, yaml
for p in pathlib.Path('mas').rglob('*.yaml'):
    yaml.safe_load(p.read_text())
    print('OK', p)
PY
```

Load secrets into Vault using the generated loader scripts:

```bash
bash vault/drroc4-load-secrets.sh
bash vault/roc4-load-secrets.sh
```

Do not commit real secret values.
