
#!/usr/bin/env python3
"""Render MAS GitOps config from base/ templates + envs/<cluster>.env.

IBM-aligned (hub-and-spoke): ONE config repo branch holds EVERY cluster directory.
Output is written to ./mas/<CLUSTER_ID>/...  at the repo root - exactly what the single
Account Root Application's cluster ApplicationSet globs (<account>/*/...).

Usage:
  python3 render.py <cluster>     # render one cluster   (e.g. python3 render.py drroc4)
  python3 render.py --all         # render every envs/*.env
"""
import os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
VAR = re.compile(r"\$\{([A-Z0-9_]+)\}")
OPTIONAL_BLOCK = re.compile(
    r"(?ms)^# BEGIN_OPTIONAL_(?P<name>[A-Z0-9_]+)\n(?P<body>.*?)^# END_OPTIONAL_(?P=name)\n?"
)

INSTANCE_TEMPLATE_FLAGS = {
    "ibm-mas-masapp-configs.yaml": "ENABLE_MANAGE",
    "ibm-mas-masapp-manage-install.yaml": "ENABLE_MANAGE",
}

def load_env(path):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            v = re.sub(r"\s+#.*$", "", v).strip()   # strip inline comments (e.g. VAL  # note)
            env[k.strip()] = v
    return env

def render(text, env, src):
    def optional(m):
        key = f"ENABLE_{m.group('name')}"
        enabled = str(env.get(key, "false")).lower() in ("1", "true", "yes")
        return m.group("body") if enabled else ""
    text = OPTIONAL_BLOCK.sub(optional, text)
    missing = sorted({m.group(1) for m in VAR.finditer(text) if m.group(1) not in env})
    if missing: sys.exit(f"ERROR: {src}: unset variables {missing}")
    rendered = VAR.sub(lambda m: env[m.group(1)], text)
    if "CHANGE_ME" in rendered:
        bad = sorted({line.strip() for line in rendered.splitlines() if "CHANGE_ME" in line})
        sys.exit(f"ERROR: {src}: rendered output still contains placeholders: {bad}")
    return rendered

def truthy(value):
    return str(value).lower() in ("1", "true", "yes")

def write(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
    if mode: os.chmod(path, mode)


def render_one(name):
    envfile = os.path.join(HERE, "envs", f"{name}.env")
    if not os.path.exists(envfile): sys.exit(f"no env file: {envfile}")
    env = load_env(envfile); cid, iid = env["CLUSTER_ID"], env["INSTANCE_ID"]
    # Cluster-scoped ownership is explicit. If another platform process owns one
    # of these resources, do not render its file; IBM account-root gates those
    # Applications on file presence. SHARED_CLUSTER_SKIP remains as a low-level
    # compatibility override for any additional files that must be suppressed.
    skip = {s.strip() for s in env.get("SHARED_CLUSTER_SKIP", "").split(",") if s.strip()}
    if not truthy(env.get("GITOPS_OWNS_CERT_MANAGER", "true")):
        skip.add("redhat-cert-manager.yaml")
    if not truthy(env.get("GITOPS_OWNS_DRO", "true")):
        skip.add("ibm-dro.yaml")
    # clean stale rendered output so removed templates don't leave orphan files
    import glob as _g
    for f in _g.glob(os.path.join(HERE, "mas", cid, "*.yaml")) + _g.glob(os.path.join(HERE, "mas", cid, iid, "*.yaml")):
        os.remove(f)
    skipped = []
    for tpl in sorted(os.listdir(os.path.join(HERE, "base", "cluster"))):
        out = tpl[:-4]
        if out in skip:
            skipped.append(out); continue
        write(os.path.join(HERE, "mas", cid, out),
              render(open(os.path.join(HERE, "base", "cluster", tpl)).read(), env, tpl))
    instance_skipped = []
    for tpl in sorted(os.listdir(os.path.join(HERE, "base", "instance"))):
        out = tpl[:-4]
        flag = INSTANCE_TEMPLATE_FLAGS.get(out)
        if flag and not truthy(env.get(flag, "false")):
            instance_skipped.append(out)
            continue
        write(os.path.join(HERE, "mas", cid, iid, out),
              render(open(os.path.join(HERE, "base", "instance", tpl)).read(), env, tpl))
    all_skipped = skipped + instance_skipped
    note = f"  (skipped {', '.join(all_skipped)})" if all_skipped else ""
    print(f"Rendered {name} -> mas/{cid}/{note}  (secrets are loaded from platform-gitops/scripts)")

def main():
    if len(sys.argv) != 2: sys.exit("usage: python3 render.py <cluster>|--all")
    if sys.argv[1] == "--all":
        for f in sorted(glob.glob(os.path.join(HERE, "envs", "*.env"))):
            render_one(os.path.basename(f)[:-4])
    else:
        render_one(sys.argv[1])

if __name__ == "__main__":
    main()
