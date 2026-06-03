#!/usr/bin/env python3
"""手动构建 fizz wheel，无需 setuptools/wheel 依赖。"""

import hashlib
import io
import os
import zipfile
import base64

PKG_NAME = "fizz"
VERSION = "0.1.0"
PYTHON_TAG = "cp312"
ABI_TAG = "none"
PLAT_TAG = "any"
WHL_NAME = f"{PKG_NAME}-{VERSION}-{PYTHON_TAG}-{ABI_TAG}-{PLAT_TAG}.whl"

SRC_DIR = os.path.join(os.path.dirname(__file__), "src", PKG_NAME)
DIST_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist")
LICENSE_FILE = os.path.join(os.path.dirname(__file__), "LICENSE")
README_FILE = os.path.join(os.path.dirname(__file__), "README.md")

METADATA = f"""Metadata-Version: 2.1
Name: {PKG_NAME}
Version: {VERSION}
Summary: SV file merger with VCS Protect, Obfuscator and RLskit support
Home-page: https://github.com/MaNan93/code
Author: Developer
License: MIT
Keywords: verilog systemverilog merge vcs obfuscate rlskit
Classifier: Development Status :: 4 - Beta
Classifier: Intended Audience :: Developers
Classifier: License :: OSI Approved :: MIT License
Classifier: Programming Language :: Python :: 3
Classifier: Programming Language :: Python :: 3.12
Classifier: Programming Language :: Python :: 3.13
Classifier: Topic :: Software Development :: Libraries :: Python Modules
Classifier: Topic :: Utilities
Requires-Python: >=3.12

"""

WHEEL_FILE = f"""Wheel-Version: 1.0
Generator: manual-build
Root-Is-Purelib: true
Tag: {PYTHON_TAG}-{ABI_TAG}-{PLAT_TAG}
"""

ENTRY_POINTS = f"""[console_scripts]
{PKG_NAME} = {PKG_NAME}.fizz:main
"""

TOP_LEVEL = f"{PKG_NAME}\n"

DIST_INFO = f"{PKG_NAME}-{VERSION}.dist-info"


def sha256_b64(data: bytes) -> str:
    h = hashlib.sha256(data).digest()
    return "sha256=" + base64.urlsafe_b64encode(h).rstrip(b"=").decode()


def main():
    os.makedirs(DIST_DIR, exist_ok=True)
    out_path = os.path.join(DIST_DIR, WHL_NAME)

    records = []  # (arcname, hash_str, size)

    def add_file(zf, arcname, data: bytes):
        zf.writestr(arcname, data)
        records.append((arcname, sha256_b64(data), str(len(data))))

    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        # 1. 包源码
        for fname in os.listdir(SRC_DIR):
            fpath = os.path.join(SRC_DIR, fname)
            if not os.path.isfile(fpath):
                continue
            with open(fpath, "rb") as f:
                data = f.read()
            arcname = f"{PKG_NAME}/{fname}"
            add_file(zf, arcname, data)

        # 2. dist-info/licenses/LICENSE
        if os.path.isfile(LICENSE_FILE):
            with open(LICENSE_FILE, "rb") as f:
                lic_data = f.read()
            add_file(zf, f"{DIST_INFO}/licenses/LICENSE", lic_data)

        # 3. dist-info/METADATA (append README)
        meta = METADATA.encode("utf-8")
        if os.path.isfile(README_FILE):
            with open(README_FILE, "rb") as f:
                readme_data = f.read()
            meta += readme_data
        add_file(zf, f"{DIST_INFO}/METADATA", meta)

        # 4. dist-info/WHEEL
        add_file(zf, f"{DIST_INFO}/WHEEL", WHEEL_FILE.encode("utf-8"))

        # 5. dist-info/entry_points.txt
        add_file(zf, f"{DIST_INFO}/entry_points.txt", ENTRY_POINTS.encode("utf-8"))

        # 6. dist-info/top_level.txt
        add_file(zf, f"{DIST_INFO}/top_level.txt", TOP_LEVEL.encode("utf-8"))

        # 7. RECORD (last, no hash for itself)
        record_lines = [f"{arc},{h},{s}" for arc, h, s in records]
        record_lines.append(f"{DIST_INFO}/RECORD,,")
        record_data = "\n".join(record_lines) + "\n"
        zf.writestr(f"{DIST_INFO}/RECORD", record_data)

    print(f"[OK] Built: {out_path}")
    print(f"     Size : {os.path.getsize(out_path):,} bytes")


if __name__ == "__main__":
    main()
