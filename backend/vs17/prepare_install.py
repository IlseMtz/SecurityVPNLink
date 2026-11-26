"""Prepare a minimal agent overlay against the actual installed V6 source."""

import argparse
import ast
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.read_text(encoding='utf-8')
import_line = 'from pathlib import Path\n'
apply_line = "        run(['/usr/bin/wg','syncconf','wg0',name])"
dispatch_line = 'def dispatch(req):\n'
for anchor in (import_line, apply_line, dispatch_line):
    if source.count(anchor) != 1:
        raise SystemExit('El agente no tiene la estructura V6 esperada. Revisar el diff antes de instalar.')
if 'import agent_resources' in source:
    raise SystemExit('VS-17 ya está instalado en este agente.')
source = source.replace(import_line, import_line + '\nimport agent_resources\n')
source = source.replace(apply_line, '''        current = dict(line.split(None, 1) for line in
            run(['/usr/bin/wg','show','wg0','allowed-ips']).splitlines() if line)
        target = {p['publicKey']:p['address']+'/32' for p in state.values() if peer_enabled(p)}
        if current != target:
            agent_resources.revoke_before_peer_change()
''' + apply_line)
source = source.replace(dispatch_line, dispatch_line + '''    if req.get('op') == 'resource_sync':
        peers = run(['/usr/bin/wg','show','wg0','allowed-ips'])
        return agent_resources.apply_snapshot(req, peers)
''')
ast.parse(source)
args.output.write_text(source, encoding='utf-8')
