#!/usr/bin/env python3
"""Render MAS GitOps config from base/ templates + envs/<cluster>.env.

IBM-aligned (hub-and-spoke): ONE config repo branch holds EVERY cluster directory.
Output is written to ./mas/<CLUSTER_ID>/...  at the repo root - exactly what the single
Account Root Application's cluster ApplicationSet globs (<account>/*/...).

Usage:
  python3 render.py <cluster>     # render one cluster   (e.g. python3 render.py drroc4)
  python3 render.py --all         # render every envs/*.env
Vault loader for each cluster is written to ./vault/<CLUSTER_ID>-load-secrets.sh
"""
import os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
VAR = re.compile(r"\$\{([A-Z0-9_]+)\}")

def load_env(path):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1); env[k.strip()] = v.strip()
    return env

def render(text, env, src):
    missing = sorted({m.group(1) for m in VAR.finditer(text) if m.group(1) not in env})
    if missing: sys.exit(f"ERROR: {src}: unset variables {missing}")
    return VAR.sub(lambda m: env[m.group(1)], text)

def write(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
    if mode: os.chmod(path, mode)

def render_one(name):
    envfile = os.path.join(HERE, "envs", f"{name}.env")
    if not os.path.exists(envfile): sys.exit(f"no env file: {envfile}")
    env = load_env(envfile); cid, iid = env["CLUSTER_ID"], env["INSTANCE_ID"]
    for tpl in sorted(os.listdir(os.path.join(HERE, "base", "cluster"))):
        write(os.path.join(HERE, "mas", cid, tpl[:-4]),
              render(open(os.path.join(HERE, "base", "cluster", tpl)).read(), env, tpl))
    for tpl in sorted(os.listdir(os.path.join(HERE, "base", "instance"))):
        write(os.path.join(HERE, "mas", cid, iid, tpl[:-4]),
              render(open(os.path.join(HERE, "base", "instance", tpl)).read(), env, tpl))
    vtpl = os.path.join(HERE, "base", "vault", "load-secrets.sh.tpl")
    write(os.path.join(HERE, "vault", f"{cid}-load-secrets.sh"),
          render(open(vtpl).read(), env, "load-secrets.sh.tpl"), mode=0o755)
    print(f"Rendered {name} -> mas/{cid}/  (+ vault/{cid}-load-secrets.sh)")

def main():
    if len(sys.argv) != 2: sys.exit("usage: python3 render.py <cluster>|--all")
    if sys.argv[1] == "--all":
        for f in sorted(glob.glob(os.path.join(HERE, "envs", "*.env"))):
            render_one(os.path.basename(f)[:-4])
    else:
        render_one(sys.argv[1])

if __name__ == "__main__":
    main()
