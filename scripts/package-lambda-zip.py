#!/usr/bin/env python3
"""Package a dotnet publish (linux-x64) output into a Lambda-ready zip.

Windows zip tools (PowerShell's Compress-Archive included) don't preserve
Unix file permissions, so a zip built there never carries the executable
bit AWS Lambda's provided.al2023 runtime needs on `bootstrap`. This sets it
explicitly via ZipInfo.external_attr before writing each entry.

Usage: python package-lambda-zip.py <publish_dir> <output_zip>
"""

import os
import sys
import zipfile

publish_dir, output_zip = sys.argv[1], sys.argv[2]

apphost = os.path.join(publish_dir, "DocLens.Lambda")
bootstrap = os.path.join(publish_dir, "bootstrap")
if os.path.exists(apphost):
    if os.path.exists(bootstrap):
        os.remove(bootstrap)
    os.rename(apphost, bootstrap)

if os.path.exists(output_zip):
    os.remove(output_zip)

with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in sorted(os.listdir(publish_dir)):
        path = os.path.join(publish_dir, name)
        if not os.path.isfile(path):
            continue
        info = zipfile.ZipInfo(name)
        info.compress_type = zipfile.ZIP_DEFLATED
        # 0755 for bootstrap (must be executable), 0644 for everything else,
        # packed into external_attr's high 16 bits per the Unix zip convention.
        mode = 0o755 if name == "bootstrap" else 0o644
        info.external_attr = (mode << 16)
        with open(path, "rb") as f:
            zf.writestr(info, f.read())

print(f"Wrote {output_zip}")
