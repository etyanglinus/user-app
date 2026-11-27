#!/usr/bin/env python3
"""Fail CI when a Flutter test fails that is not listed in test/ci/known-failures.txt.

usage: flutter_ratchet.py REPORT_JSON KNOWN_FAILURES_TXT   (report from --file-reporter json:...)
"""
import json, sys

report, known_path = sys.argv[1], sys.argv[2]
known = {l.strip() for l in open(known_path) if l.strip() and not l.startswith('#')}
names, failed, passed = {}, set(), set()
for line in open(report):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get('type') == 'testStart':
        names[e['test']['id']] = e['test']['name']
    elif e.get('type') == 'testDone' and not e.get('hidden') and not e.get('skipped'):
        n = names.get(e['testID'], str(e['testID']))
        (passed if e.get('result') == 'success' else failed).add(n)
new, fixed = sorted(failed - known), sorted(known & passed)
print(f"passed: {len(passed)}, failed: {len(failed)} (new {len(new)}), known now passing: {len(fixed)}")
for t in new: print(f"  NEW failure: {t}")
for t in fixed: print(f"  now passing, remove from list: {t}")
sys.exit(1 if new else 0)
