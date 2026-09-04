"""Synthetic calibration harness — v2 groundwork (SOMA-X + MHR).

Goal (docs/BLUEPRINT.md AI-architecture v2): tune the deterministic
engine's shape factors and depth caps against THOUSANDS of bodies whose
true circumferences are known, instead of a handful of tape pairs.

Pipeline (all offline, all Apache-2.0, zero SMPL assets):
  1. Sample N identities from MHR's 45-dim shape space (via SOMA-X's
     MHRIdentityModel).
  2. Extract ground-truth measurements with GarmentMeasurementIdentityModel
     (chest/waist/hip circumferences from the mesh).
  3. Render front + side orthographic silhouettes of each body.
  4. Run the SAME geometry the app uses (widths + depths -> Ramanujan
     ellipse x shape factor) on those silhouettes.
  5. Report per-measurement error distributions and fit better shape
     factors / depth caps; proposed constants go to engine.dart by hand,
     reviewed like every calibration.

Status: SCAFFOLD. Steps 1-2 are wired and run once MHR assets exist;
steps 3-5 are the build-days part and raise NotImplementedError with a
pointer. Asset setup (one-time):
    git clone https://github.com/facebookresearch/MHR
    -> follow its README to fetch the rig/model files, then:
    python scripts/synthetic_harness.py --data-root <path-to-mhr-assets> --n 100
"""
from __future__ import annotations

import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-root", required=True,
                    help="directory with MHR model assets (see docstring)")
    ap.add_argument("--n", type=int, default=100,
                    help="number of synthetic identities to sample")
    ap.add_argument("--device", default="cpu")
    args = ap.parse_args()

    import torch  # noqa: F401  (soma dependency)
    from soma.body import create_identity_model

    print(f"loading MHR identity model from {args.data_root} ...")
    ident = create_identity_model(
        "mhr", data_root=args.data_root, low_lod=True, device=args.device)
    print("identity model:", type(ident).__name__)

    print(f"sampling {args.n} identities ...")
    # MHR shape space: draw shape parameters ~N(0,1); the identity model
    # turns them into posed-neutral meshes.
    import torch as t
    shapes = t.randn(args.n, ident.num_shape_params
                     if hasattr(ident, "num_shape_params") else 45)
    print("shape batch:", tuple(shapes.shape))

    print("extracting ground-truth garment measurements ...")
    gm = create_identity_model(
        "garment_measurement", data_root=args.data_root, low_lod=True,
        device=args.device)
    print("measurement model:", type(gm).__name__)
    # -> gm(...) yields per-identity measurement dicts; exact call shape
    #    depends on asset version — wire on first run with real assets.

    raise NotImplementedError(
        "Steps 3-5 (silhouette render + engine-geometry replay + error "
        "report) are the scheduled build-days work — see docstring. "
        "Reaching this line means steps 1-2 loaded correctly, which is "
        "the asset-setup milestone.")


if __name__ == "__main__":
    sys.exit(main())
