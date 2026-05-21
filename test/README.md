# Tests

```sh
pip install -r requirements.txt
python run.py
```

9 cocotb tests, all black-box (external pins only), so they pass under both
RTL and the LibreLane gate-level netlist. Source: [test.py](test.py).

For gate-level sim (after LibreLane has run in CI):

```sh
make -B GATES=yes
```
