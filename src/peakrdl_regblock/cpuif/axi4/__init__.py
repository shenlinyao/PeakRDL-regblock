from typing import List

from ..base import CpuifBase
from ...utils import clog2


class AXI4_Cpuif(CpuifBase):
    """
    Full AXI4 slave CPU interface with burst support.

    Decomposes AXI4 bursts (INCR/FIXED/WRAP, narrow transfers) into
    sequential single-beat transfers on the peakrdl-regblock internal
    CPUIF protocol. One burst per direction at a time (AWREADY/ARREADY
    stay low while busy) - legal AXI4.

    Exposed as a SystemVerilog interface port (axi4_intf.slave). Instantiate
    axi4_intf (hdl-src/axi4_intf.sv) with an ID_WIDTH matching this module's
    ID_WIDTH parameter.
    """

    template_path = "axi4_tmpl.sv"
    is_interface = True

    @property
    def parameters(self) -> List[str]:
        return ["parameter ID_WIDTH = 1"]

    @property
    def port_declaration(self) -> str:
        return "axi4_intf.slave s_axi"

    def signal(self, name: str) -> str:
        return "s_axi." + name.upper()

    @property
    def regblock_latency(self) -> int:
        return max(self.exp.ds.min_read_latency, self.exp.ds.min_write_latency)

    @property
    def max_outstanding(self) -> int:
        """
        Best pipelined performance is when the max outstanding transactions
        is the design's latency + 2. Same reasoning as the built-in axi4lite.
        """
        return self.regblock_latency + 2

    @property
    def resp_buffer_size(self) -> int:
        """Read response FIFO depth; must be >= max_outstanding."""
        return self.max_outstanding

    @property
    def bus_bytes_lg(self) -> int:
        """log2 of the bus width in bytes (number of address LSBs within a bus word)."""
        return clog2(self.data_width_bytes)


class AXI4_Cpuif_flattened(AXI4_Cpuif):
    """
    Same full AXI4 cpuif, but flattens the interface into discrete
    s_axi_* input/output ports.
    """
    is_interface = False

    @property
    def port_declaration(self) -> str:
        lines = [
            # AW channel
            "output logic " + self.signal("awready"),
            "input wire " + self.signal("awvalid"),
            "input wire [ID_WIDTH-1:0] " + self.signal("awid"),
            f"input wire [{self.addr_width-1}:0] " + self.signal("awaddr"),
            "input wire [7:0] " + self.signal("awlen"),
            "input wire [2:0] " + self.signal("awsize"),
            "input wire [1:0] " + self.signal("awburst"),
            "input wire [2:0] " + self.signal("awprot"),

            # W channel
            "output logic " + self.signal("wready"),
            "input wire " + self.signal("wvalid"),
            f"input wire [{self.data_width-1}:0] " + self.signal("wdata"),
            f"input wire [{self.data_width_bytes-1}:0] " + self.signal("wstrb"),
            "input wire " + self.signal("wlast"),

            # B channel
            "input wire " + self.signal("bready"),
            "output logic " + self.signal("bvalid"),
            "output logic [ID_WIDTH-1:0] " + self.signal("bid"),
            "output logic [1:0] " + self.signal("bresp"),

            # AR channel
            "output logic " + self.signal("arready"),
            "input wire " + self.signal("arvalid"),
            "input wire [ID_WIDTH-1:0] " + self.signal("arid"),
            f"input wire [{self.addr_width-1}:0] " + self.signal("araddr"),
            "input wire [7:0] " + self.signal("arlen"),
            "input wire [2:0] " + self.signal("arsize"),
            "input wire [1:0] " + self.signal("arburst"),
            "input wire [2:0] " + self.signal("arprot"),

            # R channel
            "input wire " + self.signal("rready"),
            "output logic " + self.signal("rvalid"),
            "output logic [ID_WIDTH-1:0] " + self.signal("rid"),
            f"output logic [{self.data_width-1}:0] " + self.signal("rdata"),
            "output logic [1:0] " + self.signal("rresp"),
            "output logic " + self.signal("rlast"),
        ]
        return ",\n".join(lines)

    def signal(self, name: str) -> str:
        return "s_axi_" + name
