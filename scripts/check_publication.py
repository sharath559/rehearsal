"""Heuristic publication guard; never prints matching secret contents."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
files = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
).decode().split("\0")
bad = []
secret = re.compile(
    rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|"
    rb"(?:gh[pousr]_)[A-Za-z0-9]{30,}|"
    rb"github_pat_[A-Za-z0-9_]{40,}|"
    rb"AKIA[A-Z0-9]{16}"
)
for name in filter(None, files):
    p = pathlib.Path(name)
    if (p.name == ".env" or p.name.startswith(".env.") or p.suffix in
            {".env", ".p8", ".p12", ".pem", ".key", ".cer", ".mobileprovision", ".provisionprofile"}
            or any(part in {".runtime", "private", ".build", "DerivedData"} for part in p.parts)):
        bad.append(name)
        continue
    source = root / p
    if source.is_file() and secret.search(source.read_bytes()):
        bad.append(name)
if bad:
    print("Publication blocked; inspect these paths:")
    print("\n".join(sorted(set(bad))))
    sys.exit(1)
print(f"Publication guard passed for {len(list(filter(None, files)))} files (heuristic scan).")
