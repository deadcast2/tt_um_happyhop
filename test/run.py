# SPDX-FileCopyrightText: 2026 happyhop authors
# SPDX-License-Identifier: Apache-2.0
"""
Cross-platform cocotb runner - works without GNU make.

Usage:
    python run.py

The original Makefile is preserved for compatibility with the TT GitHub
Actions workflow, which runs in a Linux container where make is always
available.
"""

from pathlib import Path

from cocotb_tools.runner import get_runner


HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "src"

VERILOG_SOURCES = [
    SRC / "vga_sync.v",
    SRC / "pixel_logic.v",
    SRC / "tt_um_happyhop.v",
    HERE / "tb.v",
]


def main() -> None:
    runner = get_runner("icarus")
    runner.build(
        verilog_sources=VERILOG_SOURCES,
        hdl_toplevel="tb",
        build_dir=HERE / "sim_build" / "rtl",
        always=True,
    )
    runner.test(
        hdl_toplevel="tb",
        test_module="test",
        build_dir=HERE / "sim_build" / "rtl",
    )


if __name__ == "__main__":
    main()
