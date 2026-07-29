"""Shared pytest fixtures/sys.path setup for the decisive-experiment arms.

All tests here are CPU-only, synthetic-data, no network/GPU -- they exercise
the conformal-baseline math and the encoder-adapter INTERFACE CONTRACTS
(mocked encoder at the boundary), never real checkpoints.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EUROSAT_HARNESS = ROOT / "experiments" / "eurosat_xsensor_calib"
XSENSOR_HARNESS = ROOT / "experiments" / "xsensor_real"
SO2SAT_HARNESS = ROOT / "experiments" / "so2sat_coverage_debt"
BIGEARTHNET_HARNESS = ROOT / "experiments" / "bigearthnet_coverage_debt"
GEOBENCH_BATTERY_HARNESS = ROOT / "experiments" / "geobench_battery"

for _p in (EUROSAT_HARNESS, XSENSOR_HARNESS, SO2SAT_HARNESS,
          BIGEARTHNET_HARNESS, GEOBENCH_BATTERY_HARNESS):
    sp = str(_p)
    if sp not in sys.path:
        sys.path.insert(0, sp)
