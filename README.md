![](../../workflows/gds/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/fpga/badge.svg)

# happyhop

Bouncing smiley face on VGA — Tiny Tapeout **GF26a** submission, 1×1 tile,
~25% utilization. The smiley blinks every ~2 s and its eyes track its
direction of motion.

📖 [Datasheet](docs/info.md) · 🛠 [FPGA build](fpga/README.md) · 🌐 [Layout viewer](https://deadcast2.github.io/tt_um_happyhop/) · 🧪 [Tests](test/README.md)

## Simulate

```sh
cd test && pip install -r requirements.txt && python run.py
```

## Submit

Once `gds` is green on the [Actions page](https://github.com/deadcast2/tt_um_happyhop/actions),
link this repo at [app.tinytapeout.com](https://app.tinytapeout.com/) → GF26a.
