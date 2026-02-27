#!/usr/bin/env python3
"""Extract PNG screenshots from an .xcresult bundle into a flat output directory."""

import json
import os
import plistlib
import shutil
import subprocess
import sys


def run(cmd):
    return subprocess.run(cmd, capture_output=True)


def get_object(bundle, ref_id=None):
    """Fetch a JSON object from the bundle, optionally by ref ID."""
    cmd = ['xcrun', 'xcresulttool', 'get', 'object', '--legacy',
           '--path', bundle, '--format', 'json']
    if ref_id:
        cmd += ['--id', ref_id]
    result = run(cmd)
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def find_attachments_recursive(bundle, node, visited=None):
    """Walk the object graph following Reference IDs to find ActionTestAttachment nodes."""
    if visited is None:
        visited = set()
    if isinstance(node, dict):
        type_name = node.get('_type', {}).get('_name', '')
        if type_name == 'ActionTestAttachment':
            payload = node.get('payloadRef', {})
            if isinstance(payload, dict):
                ref = payload.get('id', payload.get('_value', ''))
                if isinstance(ref, dict):
                    ref = ref.get('_value', '')
            else:
                ref = ''
            name = node.get('name', 'screenshot')
            if isinstance(name, dict):
                name = name.get('_value', 'screenshot')
            uti = node.get('uniformTypeIdentifier', '')
            if isinstance(uti, dict):
                uti = uti.get('_value', '')
            if ref and ('png' in uti.lower() or 'image' in uti.lower()):
                yield ref, name
        elif type_name == 'Reference':
            ref_id = node.get('id', '')
            if isinstance(ref_id, dict):
                ref_id = ref_id.get('_value', '')
            if ref_id and ref_id not in visited:
                visited.add(ref_id)
                child = get_object(bundle, ref_id)
                if child:
                    yield from find_attachments_recursive(bundle, child, visited)
        else:
            for v in node.values():
                yield from find_attachments_recursive(bundle, v, visited)
    elif isinstance(node, list):
        for v in node:
            yield from find_attachments_recursive(bundle, v, visited)


def export_via_xcresulttool(bundle, out_dir):
    """Xcode 16+: walk the object graph following References to find all attachments."""
    root = get_object(bundle)
    if root is None:
        print("xcresulttool get object --legacy failed", file=sys.stderr)
        return False

    print("Used: xcresulttool get object --legacy (recursive)")
    count = 0
    for i, (ref, name) in enumerate(find_attachments_recursive(bundle, root)):
        safe = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        dest = os.path.join(out_dir, f'{i:02d}-{safe}.png')
        r = run(['xcrun', 'xcresulttool', 'export', 'object', '--legacy',
                 '--path', bundle, '--id', ref,
                 '--output-path', dest, '--type', 'file'])
        if r.returncode != 0:
            print(f"Warning: failed to export '{name}' (rc={r.returncode}): "
                  f"{r.stderr.decode().strip()}", file=sys.stderr)
        else:
            print(f"Exported: {dest}")
            count += 1
    return count > 0


def export_via_get_legacy(bundle, out_dir):
    """Older Xcode: use 'xcresulttool get --legacy' + raw format per attachment."""
    result = run(['xcrun', 'xcresulttool', 'get', '--legacy',
                  '--path', bundle, '--format', 'json'])
    if result.returncode != 0:
        print(f"xcresulttool get --legacy failed (rc={result.returncode}): "
              f"{result.stderr.decode().strip()}", file=sys.stderr)
        return False

    print("Used: xcresulttool get --legacy")
    data = json.loads(result.stdout)
    count = 0
    for i, (ref, name) in enumerate(find_attachments_recursive(bundle, data)):
        safe = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        dest = os.path.join(out_dir, f'{i:02d}-{safe}.png')
        r = run(['xcrun', 'xcresulttool', 'get', '--legacy',
                 '--path', bundle, '--id', ref, '--format', 'raw'])
        if r.returncode != 0:
            print(f"Warning: failed to export '{name}': {r.stderr.decode().strip()}", file=sys.stderr)
        else:
            with open(dest, 'wb') as f:
                f.write(r.stdout)
            print(f"Exported: {dest}")
            count += 1
    return count > 0


def export_via_filesystem(bundle, out_dir):
    """Last resort: copy raw attachment files from inside the .xcresult bundle."""
    print("Falling back to filesystem scan of .xcresult bundle...")
    attachments_dir = os.path.join(bundle, 'Attachments')
    search_root = attachments_dir if os.path.isdir(attachments_dir) else bundle
    count = 0
    for root, _, files in os.walk(search_root):
        for fname in files:
            src = os.path.join(root, fname)
            if os.path.getsize(src) == 0:
                continue
            _, ext = os.path.splitext(fname)
            dest_name = fname if ext else fname + '.png'
            dest = os.path.join(out_dir, dest_name)
            base, dext = os.path.splitext(dest)
            n = 1
            while os.path.exists(dest):
                dest = f"{base}_{n}{dext}"
                n += 1
            shutil.copy2(src, dest)
            print(f"Exported: {dest}")
            count += 1
    return count


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <bundle.xcresult> <output_dir>")
        sys.exit(1)

    bundle, out_dir = sys.argv[1], sys.argv[2]

    if not os.path.exists(bundle):
        print(f"Error: bundle not found: {bundle}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(out_dir, exist_ok=True)

    if not export_via_xcresulttool(bundle, out_dir):
        if not export_via_get_legacy(bundle, out_dir):
            export_via_filesystem(bundle, out_dir)

    count = sum(1 for f in os.listdir(out_dir)
                if os.path.isfile(os.path.join(out_dir, f)))
    if count == 0:
        print("No screenshots found in result bundle.")
    else:
        print(f"Done: {count} screenshot(s) exported to {out_dir}")


if __name__ == '__main__':
    main()

