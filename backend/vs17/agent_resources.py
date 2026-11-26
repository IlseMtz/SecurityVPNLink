"""Enforces short-lived authorizations on the dedicated lab bridge."""

import base64
import ipaddress
import math
import subprocess
import time

SET_NAME = 'sl_lab_live'
STAGING = 'sl_lab_next'
LAB = ipaddress.ip_network('172.30.77.0/24')
POOL = ipaddress.ip_network('10.78.0.0/16')
LEASE_MS = 5000


def ipset(*args, data=None):
    subprocess.run(['/usr/sbin/ipset', *args], input=data, text=True,
                   capture_output=True, check=True, timeout=2)


def revoke_before_peer_change():
    ipset('flush', SET_NAME)


def apply_snapshot(request, wg):
    captured = request['capturedAt']
    now = int(time.time() * 1000)
    if type(captured) is not int or not 0 <= now - captured < LEASE_MS:
        raise ValueError('Snapshot expirado')
    rows = request['entries']
    if not isinstance(rows, list) or len(rows) > 1024:
        raise ValueError('Snapshot fuera de capacidad')

    peers = dict(line.split(None, 1) for line in wg.splitlines() if line)
    entries = {}
    for key, address, protocol, port, destination, expires in rows:
        if len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError('Clave pública inválida')
        source = ipaddress.IPv4Address(address)
        target = ipaddress.IPv4Address(destination)
        if source not in POOL or target not in LAB or not 2 <= int(target) % 256 <= 254:
            raise ValueError('Dirección fuera del laboratorio')
        if protocol not in ('TCP', 'UDP') or type(port) is not int or not 1 <= port <= 65535:
            raise ValueError('Protocolo o puerto inválido')
        if type(expires) is not int or expires > captured + LEASE_MS:
            raise ValueError('Vigencia inválida')
        if peers.get(key) != f'{source}/32':
            continue
        entry = f'{source},{protocol.lower()}:{port},{target}'
        entries[entry] = max(entries.get(entry, 0), expires)

    ipset('flush', STAGING)
    now = math.ceil(time.time() * 1000)
    # Round down. No element may survive the next schedule boundary.
    commands = [f'add {STAGING} {entry} timeout {(expires - now) // 1000}'
                for entry, expires in entries.items() if expires - now >= 1000]
    if commands:
        ipset('restore', data='\n'.join(commands) + '\n')
    ipset('swap', STAGING, SET_NAME)
    return {'ok': True, 'applied': len(commands)}
