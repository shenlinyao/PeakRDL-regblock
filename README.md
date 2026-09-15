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

### Release flow (Environment Modules)

The fork releases itself as a versioned, self-contained peakrdl tool module —
the same model as `eda_wrapper`. `scripts/release.sh` builds a virtualenv at
`$HOME/releases/peakrdl/<version>/` containing peakrdl-regblock **installed
from this local repo** (`git archive <ref>` — never fetched from GitHub/PyPI)
plus `peakrdl`, `peakrdl-uvm`, `peakrdl-docx` from PyPI, and writes a
modulefile at `$HOME/releases/modulefiles/peakrdl/<version>`.

```bash
# from the repo root, on dev/axi4-cpuif
scripts/release.sh --version 1.3.1-axi4.1            # release HEAD
scripts/release.sh --version 1.3.1-axi4.2 --ref dev/axi4-cpuif
```

* Version naming: the module version is independent of the package version;
  `-` reads better than `+` in module names (`1.3.1-axi4.1` ↔ package
  `1.3.1+axi4.1`).
* The script smoke-tests that the released venv lists the built-in `axi4`
  cpuif, ships `hdl-src/regblock_udps.rdl` as
  `<prefix>/share/regblock_udps.rdl`, promotes the module default (unless
  `--no-default`), prunes old releases (keeps newest 5,
  `$PEAKRDL_RELEASE_KEEP`), and verifies via `modulecmd`.
* Env overrides: `$PEAKRDL_RELEASE_ROOT`, `$PEAKRDL_RELEASE_PYTHON`.

Consumers:

```tcsh
module use /home/leons/releases/modulefiles   # one-time, e.g. in ~/.cshrc
module load peakrdl                           # or peakrdl/<version>
peakrdl regblock --cpuif axi4 $PEAKRDL_HOME/share/regblock_udps.rdl your.rdl -o rtl/
```


---

# PeakRDL-regblock
Compile SystemRDL into a SystemVerilog control/status register (CSR) block.

For the command line tool, see the [PeakRDL project](https://peakrdl.readthedocs.io).

## Documentation
See the [PeakRDL-regblock Documentation](https://peakrdl-regblock.readthedocs.io) for more details
