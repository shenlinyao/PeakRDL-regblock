[![Documentation Status](https://readthedocs.org/projects/peakrdl-regblock/badge/?version=latest)](http://peakrdl-regblock.readthedocs.io)
[![build](https://github.com/SystemRDL/PeakRDL-regblock/workflows/build/badge.svg)](https://github.com/SystemRDL/PeakRDL-regblock/actions?query=workflow%3Abuild+branch%3Amain)
[![Coverage Status](https://coveralls.io/repos/github/SystemRDL/PeakRDL-regblock/badge.svg?branch=main)](https://coveralls.io/github/SystemRDL/PeakRDL-regblock?branch=main)
[![PyPI - Python Version](https://img.shields.io/pypi/pyversions/peakrdl-regblock.svg)](https://pypi.org/project/peakrdl-regblock)

# PeakRDL-regblock (fork: shenlinyao)

> **This is a fork of [SystemRDL/PeakRDL-regblock](https://github.com/SystemRDL/PeakRDL-regblock)**
> (LGPLv3, license and notices retained). Local changes live on branch
> `dev/axi4-cpuif`:
>
> * **Full AXI4 (burst-capable) cpuif** — `--cpuif axi4`. Bursts
>   (INCR/FIXED/WRAP, narrow transfers) are decomposed into sequential
>   single-beat transfers on the internal protocol. See
>   `docs/cpuif/axi4.rst` and `src/peakrdl_regblock/cpuif/axi4/`.
> * **Cherry-picked upstream PR #209** — fix for arrays of external
>   components with buffered registers (issue #208).
>
> Install: `pip install "git+ssh://git@github.com/shenlinyao/PeakRDL-regblock.git@dev/axi4-cpuif"`

---

# PeakRDL-regblock
Compile SystemRDL into a SystemVerilog control/status register (CSR) block.

For the command line tool, see the [PeakRDL project](https://peakrdl.readthedocs.io).

## Documentation
See the [PeakRDL-regblock Documentation](https://peakrdl-regblock.readthedocs.io) for more details
