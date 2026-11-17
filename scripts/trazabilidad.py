#!/usr/bin/env python3
"""
Tabla de trazabilidad escenario → verificación.

Recorre todos los escenarios de volutrainmed-openspec/openspec/changes/*/specs/*/spec.md
y busca en las suites de pruebas (motor, API, app Flutter y back office) una prueba
cuyo nombre contenga el nombre del escenario. El resultado se combina con las
anotaciones manuales de scripts/trazabilidad-manual.json (verificación manual en
dispositivo, simulado o no ejecutable por un agente) y se escribe en
docs/trazabilidad.md.

Uso: python3 -I scripts/trazabilidad.py
"""
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGES = os.path.join(ROOT, 'volutrainmed-openspec', 'openspec', 'changes')
TEST_DIRS = [
    os.path.join(ROOT, 'packages', 'engine', 'test'),
    os.path.join(ROOT, 'services', 'api', 'test'),
    os.path.join(ROOT, 'apps', 'mobile', 'test'),
    os.path.join(ROOT, 'apps', 'mobile', 'integration_test'),
    os.path.join(ROOT, 'apps', 'backoffice', 'src'),
    os.path.join(ROOT, 'apps', 'backoffice', 'e2e'),
    os.path.join(ROOT, 'apps', 'backoffice', 'tests'),
]
TEST_EXT = ('.ts', '.tsx', '.dart')


def norm(s: str) -> str:
    s = unicodedata.normalize('NFD', s.lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = re.sub(r'[«»"\'`]', '', s)
    return re.sub(r'\s+', ' ', s).strip()


def scenarios():
    out = []
    for change in sorted(os.listdir(CHANGES)):
        specs = os.path.join(CHANGES, change, 'specs')
        if not os.path.isdir(specs):
            continue
        for cap in sorted(os.listdir(specs)):
            path = os.path.join(specs, cap, 'spec.md')
            if not os.path.exists(path):
                continue
            req = None
            kind = 'ADDED'
            for line in open(path, encoding='utf-8'):
                if line.startswith('## MODIFIED'):
                    kind = 'MODIFIED'
                if line.startswith('### Requirement:'):
                    req = line.split(':', 1)[1].strip()
                elif line.startswith('#### Scenario:'):
                    out.append({'change': change, 'capability': cap, 'requirement': req, 'scenario': line.split(':', 1)[1].strip(), 'delta': kind})
    return out


def test_corpus():
    corpus = []
    for d in TEST_DIRS:
        if not os.path.isdir(d):
            continue
        for base, _dirs, files in os.walk(d):
            if 'node_modules' in base:
                continue
            for f in files:
                if not f.endswith(TEST_EXT):
                    continue
                if not (('test' in f) or ('spec' in f) or base.endswith(('test', 'integration_test', 'e2e', 'tests'))):
                    continue
                p = os.path.join(base, f)
                try:
                    txt = open(p, encoding='utf-8').read()
                except Exception:
                    continue
                corpus.append((os.path.relpath(p, ROOT), norm(txt)))
    return corpus


def main():
    scs = scenarios()
    corpus = test_corpus()
    manual_path = os.path.join(ROOT, 'scripts', 'trazabilidad-manual.json')
    manual = json.load(open(manual_path, encoding='utf-8')) if os.path.exists(manual_path) else {}
    rows = []
    counts = {}
    for s in scs:
        key = f"{s['capability']}::{s['scenario']}"
        n = norm(s['scenario'])
        hits = [p for p, txt in corpus if n in txt]
        m = manual.get(key)
        if hits:
            status = 'Prueba automatizada'
            evidence = ', '.join(sorted(set(hits)))
            if m and m.get('note'):
                evidence += f" · {m['note']}"
        elif m:
            status = m['status']
            evidence = m.get('note', '')
        else:
            status = 'Sin evidencia automática'
            evidence = ''
        counts[status] = counts.get(status, 0) + 1
        rows.append((s, status, evidence))
    lines = [
        '# Trazabilidad de escenarios del OpenSpec',
        '',
        'Generado con `python3 -I scripts/trazabilidad.py`. Una prueba cubre un escenario cuando su nombre contiene el nombre del escenario; el resto se anota a mano en `scripts/trazabilidad-manual.json`.',
        '',
        '| Estado | Escenarios |',
        '| --- | --- |',
    ]
    for k in sorted(counts, key=lambda x: -counts[x]):
        lines.append(f'| {k} | {counts[k]} |')
    lines.append(f'| **Total** | **{len(scs)}** |')
    current = None
    for s, status, evidence in rows:
        head = f"{s['change']} · {s['capability']}"
        if head != current:
            current = head
            lines += ['', f'## {head}', '', '| Requisito | Escenario | Estado | Evidencia |', '| --- | --- | --- | --- |']
        lines.append(f"| {s['requirement']} | {s['scenario']} | {status} | {evidence} |")
    out = os.path.join(ROOT, 'docs', 'trazabilidad.md')
    open(out, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(json.dumps(counts, ensure_ascii=False), f'total={len(scs)}', '→', os.path.relpath(out, ROOT))
    if '--missing' in sys.argv:
        for s, status, _ in rows:
            if status == 'Sin evidencia automática':
                print(f"{s['capability']}::{s['scenario']}")


if __name__ == '__main__':
    main()
