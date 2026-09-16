from ..base import CpuifTestMode

from peakrdl_regblock.cpuif.axi4 import AXI4_Cpuif, AXI4_Cpuif_flattened

class AXI4(CpuifTestMode):
    cpuif_cls = AXI4_Cpuif
    rtl_files = [
        "../../../../hdl-src/axi4_intf.sv",
    ]
    tb_files = [
        "../../../../hdl-src/axi4_intf.sv",
        "axi4_driver.sv",
    ]
    tb_template = "tb_inst.sv"

class FlatAXI4(AXI4):
    cpuif_cls = AXI4_Cpuif_flattened
    rtl_files = []
