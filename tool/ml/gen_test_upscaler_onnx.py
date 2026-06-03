#!/usr/bin/env python3
"""Generate the tiny ONNX upscaling fixture used by OnnxImageUpscaler tests.

This builds a minimal NCHW RGB model whose single ``Resize`` node (mode
``nearest``, scales ``[1, 1, 2, 2]``, opset 13) upscales ``[1, 3, H, W]`` to
``[1, 3, 2H, 2W]``. It is a black-box stand-in for a real super-resolution
model: it exercises the full decode -> tensor -> ORT CPU EP -> tensor -> encode
plumbing deterministically (nearest resize is bit-stable, no interpolation).

The resulting binary is **committed** at
``app/test/fixtures/ml/upscale_x2_nearest.onnx``; Python and the ``onnx``
package are NOT needed at test time. This script exists only so the fixture is
reproducible.

Usage (dev-only):
    pip install onnx
    python3 tool/ml/gen_test_upscaler_onnx.py
"""

from __future__ import annotations

import os

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

OUT_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "test",
    "fixtures",
    "ml",
    "upscale_x2_nearest.onnx",
)

OPSET = 13


def build_model() -> onnx.ModelProto:
    # Dynamic spatial dims so the same model upscales any size.
    input_vi = helper.make_tensor_value_info(
        "input", TensorProto.FLOAT, [1, 3, "H", "W"]
    )
    output_vi = helper.make_tensor_value_info(
        "output", TensorProto.FLOAT, [1, 3, "H2", "W2"]
    )

    # scales over [N, C, H, W]: keep N,C; double H,W.
    scales = numpy_helper.from_array(
        np.array([1.0, 1.0, 2.0, 2.0], dtype=np.float32), name="scales"
    )

    # opset-13 Resize: inputs are (X, roi, scales). roi is skipped with "".
    resize = helper.make_node(
        "Resize",
        inputs=["input", "", "scales"],
        outputs=["output"],
        mode="nearest",
        coordinate_transformation_mode="asymmetric",
        nearest_mode="floor",
    )

    graph = helper.make_graph(
        nodes=[resize],
        name="upscale_x2_nearest",
        inputs=[input_vi],
        outputs=[output_vi],
        initializer=[scales],
    )
    model = helper.make_model(
        graph,
        opset_imports=[helper.make_opsetid("", OPSET)],
        producer_name="geekplayer-test-fixture",
    )
    model.ir_version = 7  # compatible with onnxruntime 1.4.x / ORT 1.15
    onnx.checker.check_model(model)
    return model


def main() -> None:
    model = build_model()
    out = os.path.normpath(OUT_PATH)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    onnx.save_model(model, out)
    print(f"wrote {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
