#!/usr/bin/env python3
"""Extract PNG screenshots from an .xcresult bundle into a flat output directory."""

import json
import os
import subprocess
import sys


def find_attachments(node):
    if isinstance(node, dict):
        if node.get('_type', {}).get('_name') == 'ActionTestAttachment':
            ref = node.get('payloadRef', {}).get('id', '')
            name = node.get('name', 'screenshot')
            uti = node.get('uniformTypeIdentifier', '')
            if ref and ('png' in uti.lower() or 'image' in uti.lower()):
                yield ref, name
        for v in node.values():
            yield from find_attachments(v)
    elif isinstance(node, list):
        for v in node:
            yield from find_attachments(v)


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <bundle.xcresult> <output_dir>")
        sys.exit(1)

    bundle = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

result = subprocess.run(
        ['xcrun', 'xcresulttool', 'get', 'object', '--legacy', '--path', bundle, '--format', 'json'],
        capture_output=True
    )
    if result.returncode != 0:
        print(f"xcresulttool failed: {result.stderr.decode()}")
        sys.exit(1)

    data = json.loads(result.stdout)
    count = 0
    for i, (ref, name) in enumerate(find_attachments(data)):
        safe = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        dest = os.path.join(out_dir, f'{i:02d}-{safe}.png')
        with open(dest, 'wb') as f:
            subprocess.run(
                ['xcrun', 'xcresulttool', 'get', '--path', bundle,
                 '--id', ref, '--format', 'raw'],
                stdout=f,
                check=False
            )
        print(f'Exported: {dest}')
        count += 1

    print(f'Done: {count} screenshot(s) exported to {out_dir}')


if __name__ == '__main__':
    main()

