#!/usr/bin/env python3
"""Export the real RealESRGAN_x4plus_anime_6B checkpoint to ORT-1.15.1-ready ONNX.

add-upscale-model-selection §3.3. Produces the 4x catalog model:
  - fixed input shape [1, 3, TILE, TILE], NCHW float32 RGB in [0,1]
  - output [1, 3, TILE*4, TILE*4]  (matches OnnxImageUpscaler's tensor contract)
  - opset 17, ONNX IR version clamped to 9 (ORT 1.15.1 ceiling; see §1.5)
  - self-contained .onnx (weights inlined, no .onnx.data sidecar)

A self-contained RRDBNet (num_block=6, num_feat=64, num_grow_ch=32, scale=4) is
defined here to avoid the basicsr/torchvision dependency chain; its parameter
names match the basicsr checkpoint so `load_state_dict` works directly.

License: RealESRGAN_x4plus_anime_6B weights are BSD-3-Clause (xinntao/Real-ESRGAN,
Copyright (c) 2021 Xintao Wang) — verified against the upstream LICENSE (§3.2).

Run (isolated venv with torch + onnx; NOT in CI):
    python tool/export_real_realesrgan_x4.py \
        --ckpt /path/to/RealESRGAN_x4plus_anime_6B.pth \
        --out  /path/to/realesrgan_x4plus_anime_6b_t256.onnx --tile 256
    shasum -a 256 <out>        # -> catalog sha256
"""
from __future__ import annotations

import argparse
import os

import onnx
import torch
import torch.nn as nn
import torch.nn.functional as F

OPSET = 17
MAX_IR_VERSION = 9  # ORT 1.15.1 supports ONNX IR <= 9 (§1.5)


class ResidualDenseBlock(nn.Module):
    def __init__(self, num_feat: int = 64, num_grow_ch: int = 32):
        super().__init__()
        self.conv1 = nn.Conv2d(num_feat, num_grow_ch, 3, 1, 1)
        self.conv2 = nn.Conv2d(num_feat + num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv3 = nn.Conv2d(num_feat + 2 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv4 = nn.Conv2d(num_feat + 3 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv5 = nn.Conv2d(num_feat + 4 * num_grow_ch, num_feat, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(negative_slope=0.2, inplace=True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        return x5 * 0.2 + x


class RRDB(nn.Module):
    def __init__(self, num_feat: int, num_grow_ch: int = 32):
        super().__init__()
        self.rdb1 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb2 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb3 = ResidualDenseBlock(num_feat, num_grow_ch)

    def forward(self, x):
        out = self.rdb1(x)
        out = self.rdb2(out)
        out = self.rdb3(out)
        return out * 0.2 + x


class RRDBNet(nn.Module):
    """basicsr-compatible RRDBNet (scale=4 via two nearest-interpolate steps)."""

    def __init__(self, num_in_ch=3, num_out_ch=3, num_feat=64, num_block=6, num_grow_ch=32):
        super().__init__()
        self.conv_first = nn.Conv2d(num_in_ch, num_feat, 3, 1, 1)
        self.body = nn.Sequential(*[RRDB(num_feat, num_grow_ch) for _ in range(num_block)])
        self.conv_body = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_up1 = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_up2 = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_hr = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_last = nn.Conv2d(num_feat, num_out_ch, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(negative_slope=0.2, inplace=True)

    def forward(self, x):
        feat = self.conv_first(x)
        body_feat = self.conv_body(self.body(feat))
        feat = feat + body_feat
        feat = self.lrelu(self.conv_up1(F.interpolate(feat, scale_factor=2, mode="nearest")))
        feat = self.lrelu(self.conv_up2(F.interpolate(feat, scale_factor=2, mode="nearest")))
        return self.conv_last(self.lrelu(self.conv_hr(feat)))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tile", type=int, default=256)
    args = ap.parse_args()

    model = RRDBNet(num_block=6)
    try:
        ckpt = torch.load(args.ckpt, map_location="cpu", weights_only=True)
    except Exception:
        ckpt = torch.load(args.ckpt, map_location="cpu", weights_only=False)
    state = ckpt.get("params_ema") or ckpt.get("params") or ckpt
    model.load_state_dict(state, strict=True)
    model.eval()

    dummy = torch.rand(1, 3, args.tile, args.tile, dtype=torch.float32)
    torch.onnx.export(
        model,
        dummy,
        args.out,
        opset_version=OPSET,
        input_names=["input"],
        output_names=["output"],
        do_constant_folding=True,
    )
    m = onnx.load(args.out)
    if m.ir_version > MAX_IR_VERSION:
        m.ir_version = MAX_IR_VERSION
    onnx.save_model(m, args.out, save_as_external_data=False)
    sidecar = args.out + ".data"
    if os.path.exists(sidecar):
        os.remove(sidecar)
    # Soft well-formedness check (non-fatal; onnx's checker can raise spurious
    # version-converter errors on Resize for models that still load+run on ORT
    # 1.15.1 — the authoritative check is the Dart CPU-EP smoke / temp verify).
    try:
        onnx.checker.check_model(args.out)
    except Exception as e:  # noqa: BLE001
        print(f"  NOTE: onnx.checker reported (non-fatal): {e}")
    size = os.path.getsize(args.out)
    print(f"wrote {args.out} ({size} bytes, opset {OPSET}, IR {m.ir_version}, tile {args.tile}x4)")


if __name__ == "__main__":
    main()
