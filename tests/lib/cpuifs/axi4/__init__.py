from ..base import CpuifTestMode

from peakrdl_regblock.cpuif.axi4 import AXI4_Cpuif

class AXI4(CpuifTestMode):
    cpuif_cls = AXI4_Cpuif
    rtl_files = []
    tb_files = [
        "axi4_driver.sv",
    ]
    tb_template = "tb_inst.sv"
