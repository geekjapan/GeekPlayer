#!/usr/bin/env python3
"""Export *reduced-architecture* ONNX smoke fixtures (ADR-0007 / add-upscale-model-selection §1).

Purpose
-------
The Dart `onnxruntime` 1.4.1 package bundles native ONNX Runtime **1.15.1**
(opset <= 19). No source verified that a real Real-ESRGAN / waifu2x ONNX export
actually loads and runs on that runtime's CPU EP, so this script produces tiny
fixtures that exercise the **same op families** as the real models — at opset 17
and a fixed square tile — without shipping ~18 MB of real weights.

It deliberately does NOT reproduce the full architectures (that would match the
real parameter count and file size). It builds *minimal* variants:

- ``smoke_realesrgan_x4_arch.onnx`` — a reduced RRDBNet-style x4 net using the
  same op families as Real-ESRGAN (Conv2d, LeakyReLU, residual add, PixelShuffle
  upsampling). num_feat / num_block are minimised → a few hundred KB.
- ``smoke_waifu2x_x2_arch.onnx`` — a reduced conv x2 net (Conv2d, LeakyReLU,
  PixelShuffle). This is a lightweight stand-in; for a faithful swin_unet op
  check, also export a small-tile model from nagadomi/nunif (tasks §3.4-3.6).

Both take NCHW float32 RGB in [0,1], shape ``[1, 3, TILE, TILE]``, and emit
``[1, 3, TILE*scale, TILE*scale]`` — matching `OnnxImageUpscaler`'s tensor
contract.

Run (local; needs a PyTorch env — NOT available in CI):
    pip install torch onnx
    python tool/export_smoke_fixtures.py --out test/fixtures/ml

Then the skipped smoke test `test/core/ml/onnx_real_arch_smoke_test.dart`
activates and proves the ops load on ORT 1.15.1's CPU EP.
"""
from __future__ import annotations

import argparse
import os

import onnx
import torch
import torch.nn as nn

OPSET = 17
# ONNX Runtime 1.15.1 (bundled by the Dart `onnxruntime` 1.4.1 package) supports
# ONNX IR version <= 9. Newer torch/onnx default to IR 10, which ORT 1.15.1
# rejects with "Unsupported model IR version: 10". opset 17 is compatible with
# IR 9, so we clamp the IR version down after export. The SAME clamp is required
# for the real Real-ESRGAN / waifu2x exports (tasks §3.3 / §3.5).
MAX_IR_VERSION = 9
TILE = 64  # small fixed tile; product models use 256 (design D3)


class ReducedRRDB(nn.Module):
    """Minimal RRDBNet-style x4 net: same op families as Real-ESRGAN, tiny."""

    def __init__(self, num_feat: int = 8, num_block: int = 1, scale: int = 4):
        super().__init__()
        self.conv_first = nn.Conv2d(3, num_feat, 3, 1, 1)
        self.body = nn.ModuleList(
            [nn.Conv2d(num_feat, num_feat, 3, 1, 1) for _ in range(num_block)]
        )
        self.lrelu = nn.LeakyReLU(negative_slope=0.2, inplace=True)
        # PixelShuffle upsampling (scale must be a power of 2 here: 4 = 2*2).
        ups = []
        c = scale
        while c > 1:
            ups.append(nn.Conv2d(num_feat, num_feat * 4, 3, 1, 1))
            ups.append(nn.PixelShuffle(2))
            c //= 2
        self.upsample = nn.Sequential(*ups)
        self.conv_last = nn.Conv2d(num_feat, 3, 3, 1, 1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        feat = self.lrelu(self.conv_first(x))
        body = feat
        for conv in self.body:
            body = self.lrelu(conv(body)) + body  # residual add
        feat = feat + body
        feat = self.upsample(feat)
        return self.conv_last(feat)


class ReducedConvSR(nn.Module):
    """Minimal conv x2 net (Conv2d, LeakyReLU, PixelShuffle) — waifu2x stand-in."""

    def __init__(self, num_feat: int = 8, scale: int = 2):
        super().__init__()
        self.conv_first = nn.Conv2d(3, num_feat, 3, 1, 1)
        self.conv_mid = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(negative_slope=0.1, inplace=True)
        self.up_conv = nn.Conv2d(num_feat, num_feat * scale * scale, 3, 1, 1)
        self.shuffle = nn.PixelShuffle(scale)
        self.conv_last = nn.Conv2d(num_feat, 3, 3, 1, 1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        feat = self.lrelu(self.conv_first(x))
        feat = self.lrelu(self.conv_mid(feat))
        feat = self.shuffle(self.up_conv(feat))
        return self.conv_last(feat)


def _export(model: nn.Module, path: str) -> None:
    model.eval()
    dummy = torch.rand(1, 3, TILE, TILE, dtype=torch.float32)
    torch.onnx.export(
        model,
        dummy,
        path,
        opset_version=OPSET,
        input_names=["input"],
        output_names=["output"],
        do_constant_folding=True,
    )
    # Clamp the ONNX IR version down to what ORT 1.15.1 accepts (<= 9) and
    # inline all weights so the .onnx is self-contained (no .onnx.data sidecar,
    # which `OnnxModelSource.bytes` would not load). torch's exporter may emit an
    # external-data sidecar; re-saving without external data inlines it — then we
    # remove the now-orphaned sidecar.
    m = onnx.load(path)  # loads external data if present
    if m.ir_version > MAX_IR_VERSION:
        m.ir_version = MAX_IR_VERSION
    onnx.save(m, path, save_as_external_data=False)
    sidecar = path + ".data"
    if os.path.exists(sidecar):
        os.remove(sidecar)
    size = os.path.getsize(path)
    print(f"wrote {path} ({size} bytes, opset {OPSET}, IR {m.ir_version}, tile {TILE})")
    if size > 2_000_000:
        print(f"  WARNING: {path} is larger than expected for a smoke fixture")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="test/fixtures/ml", help="output directory")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    torch.manual_seed(0)
    _export(ReducedRRDB(scale=4), os.path.join(args.out, "smoke_realesrgan_x4_arch.onnx"))
    _export(ReducedConvSR(scale=2), os.path.join(args.out, "smoke_waifu2x_x2_arch.onnx"))


if __name__ == "__main__":
    main()
