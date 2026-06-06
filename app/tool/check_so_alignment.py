#!/usr/bin/env python3
"""Audit 16 KB page-size ELF alignment of an APK's arm64-v8a native libs.

Android 15+ moves toward 16 KB memory pages. A bundled `.so` whose LOAD
segments are not 16 KB aligned (`p_align >= 0x4000`) triggers an "Android App
Compatibility" warning on 16 KB-page devices and will eventually fail to load.

This script unzips an APK, parses the ELF program headers of every
`lib/arm64-v8a/*.so`, and verifies all PT_LOAD segments are 16 KB aligned.
Pure stdlib — no NDK / external tools — so it runs identically in CI and
locally (OpenSpec change `add-android-16kb-page-support`, design D2/Q3).

Exit code: 0 if all (non-excluded, non-known-warning) libs are aligned,
1 otherwise. Known-warning libs (default: libonnxruntime.so) are reported but
do NOT fail the run while remediation waits on upstream (design D1/Q1 = 方針 A).
Pass `--strict` to treat known-warning libs as failures too (use once
onnxruntime ships a 16 KB-aligned build).

Usage:
    python3 tool/check_so_alignment.py path/to/app.apk
    python3 tool/check_so_alignment.py app.apk --strict
"""

from __future__ import annotations

import argparse
import struct
import sys
import zipfile

PAGE_16KB = 0x4000
PT_LOAD = 1
ABI_DIR = "lib/arm64-v8a/"

# Debug-only Vulkan validation layer; never shipped in release builds.
EXCLUDE_PREFIXES = ("libVkLayer_",)

# Libs known to be unaligned with no fix available upstream yet. Reported as a
# warning (not a failure) under 方針 A. Remove entries here as they are fixed,
# then CI runs effectively strict for them. See design D1/D2.
KNOWN_WARN = {"libonnxruntime.so"}


def _basename(path: str) -> str:
    return path.rsplit("/", 1)[-1]


def max_load_align(data: bytes) -> int:
    """Return the max p_align across PT_LOAD segments of an ELF64 LE image."""
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    if data[4] != 2:  # EI_CLASS: 2 == ELFCLASS64
        raise ValueError("not ELF64 (arm64-v8a expected)")
    if data[5] != 1:  # EI_DATA: 1 == little-endian
        raise ValueError("not little-endian ELF")

    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]

    max_align = 0
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type != PT_LOAD:
            continue
        p_align = struct.unpack_from("<Q", data, off + 0x30)[0]
        max_align = max(max_align, p_align)
    return max_align


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", help="path to the APK to audit")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="treat known-warning libs (libonnxruntime.so) as failures too",
    )
    args = parser.parse_args(argv)

    try:
        zf = zipfile.ZipFile(args.apk)
    except (OSError, zipfile.BadZipFile) as exc:
        print(f"error: cannot open APK '{args.apk}': {exc}", file=sys.stderr)
        return 1

    libs = [
        n
        for n in zf.namelist()
        if n.startswith(ABI_DIR)
        and n.endswith(".so")
        and not _basename(n).startswith(EXCLUDE_PREFIXES)
    ]
    if not libs:
        print(f"error: no {ABI_DIR}*.so found in {args.apk}", file=sys.stderr)
        return 1

    failures: list[str] = []
    warnings: list[str] = []
    print(f"16 KB ELF alignment audit: {args.apk}")
    for name in sorted(libs):
        base = _basename(name)
        try:
            align = max_load_align(zf.read(name))
        except ValueError as exc:
            print(f"  SKIP  {base}: {exc}")
            continue
        aligned = align >= PAGE_16KB
        mark = "ok  " if aligned else "FAIL"
        if not aligned and base in KNOWN_WARN and not args.strict:
            mark = "warn"
        print(f"  [{mark}] {base}: max LOAD p_align=0x{align:x}")
        if aligned:
            continue
        if base in KNOWN_WARN and not args.strict:
            warnings.append(base)
        else:
            failures.append(base)

    if warnings:
        print(
            f"\n{len(warnings)} known-unaligned lib(s) tolerated (方針 A, "
            f"awaiting upstream): {', '.join(warnings)}"
        )
    if failures:
        print(
            f"\nFAILED: {len(failures)} lib(s) not 16 KB aligned: "
            f"{', '.join(failures)}",
            file=sys.stderr,
        )
        return 1
    print("\nPASS: all required libs are 16 KB aligned.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
