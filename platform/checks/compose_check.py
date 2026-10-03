"""Checks Supabase's compose file merged with the factory's changes.

    docker compose config --format json | python3 compose_check.py

Run by CI against the release setup.sh pins. Holds the promises in
supabase/platform.yml:
- nothing but Caddy is reachable from outside: every published port is
  bound to 127.0.0.1, and Caddy alone uses the host's network;
- every service has a memory ceiling, together at most 4.5 GB, leaving
  room in 8 GB for Lizarding's 2.5 GB and the system.
Standard library only.
"""

import json
import sys

PLATFORM_CEILING = 4.5 * 1024**3
problems = []
config = json.load(sys.stdin)
services = config["services"]

for name, service in sorted(services.items()):
    for port in service.get("ports", []):
        if port.get("host_ip") != "127.0.0.1":
            problems.append(f"{name} publishes port {port.get('published')} beyond this machine")
    if service.get("network_mode") == "host" and name != "caddy":
        problems.append(f"{name} uses the host's network; only caddy may")
    if not service.get("mem_limit"):
        problems.append(f"{name} has no memory ceiling")

if "caddy" not in services:
    problems.append("there is no caddy: nothing would answer on 443")
elif services["caddy"].get("network_mode") != "host":
    problems.append("caddy isn't on the host's network, so it can't reach 127.0.0.1")

total = sum(int(s.get("mem_limit", 0)) for s in services.values())
if total > PLATFORM_CEILING:
    problems.append(f"the platform's ceilings add up to {total / 1024**3:.2f} GB, over 4.5 GB")

for problem in problems:
    print("NOT TRUE:", problem)
print(f"{len(services)} services, ceilings {total / 1024**3:.2f} GB" + ("" if problems else ": all held"))
sys.exit(1 if problems else 0)
