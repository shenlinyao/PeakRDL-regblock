.. _cpuif_axi4:

AMBA AXI4 (full, burst-capable)
===============================

.. note::
    This CPU interface is a local addition of this fork
    (``shenlinyao/PeakRDL-regblock``) and is not part of upstream
    peakrdl-regblock.

Implements the register block using a full
`AMBA AXI4 <https://developer.arm.com/documentation/ihi0022/e/>`_
slave CPU interface with burst support.

* Command line: ``--cpuif axi4``
* Class: :class:`peakrdl_regblock.cpuif.axi4.AXI4_Cpuif`

Bursts are decomposed into sequential single-beat transfers on the
peakrdl-regblock internal CPUIF protocol (which is one-transfer-at-a-time,
in-order). All burst logic lives in the SystemVerilog template; the Python
class declares the flat ``s_axi_*`` port list (``ID_WIDTH`` parameterized).

Supported
---------

- Burst types: INCR, FIXED, WRAP (WRAP lengths 2/4/8/16)
- ``AxLEN`` 0-255; narrow transfers (``AxSIZE`` <= bus width) incl. unaligned
  start addresses; natural AXI byte-lane steering (no data shifting)
- Per-beat ``RRESP``; single ``BRESP`` per burst = OR-fold of per-beat errors
  (works with ``--err-if-bad-addr`` / ``--err-if-bad-rw`` to surface SLVERR)
- ``AWID``/``ARID`` echoed on ``BID``/``RID``; parameterized ``ID_WIDTH``
- Concurrent read + write bursts (round-robin per-beat arbitration on the
  internal request bus)
- External components with variable ack latency (read response FIFO)

Illegal bursts (``AxSIZE`` > bus width, ``AxBURST == 3``, bad WRAP length) are
answered with a full-length SLVERR burst without touching the register core
(writes are discarded, reads return zeros).

Not supported
-------------

- Multiple outstanding bursts per direction (AWREADY/ARREADY stay low while
  busy - legal AXI4, masters simply wait)
- Exclusive/atomic accesses (no ``AxLOCK`` ports)
- ``AxCACHE``/``AxQOS``/``AxREGION``/``AxUSER`` ports (leave unconnected at
  integration); ``AxPROT`` accepted and ignored
- DECERR encoding (SLVERR only), ID interleaving
