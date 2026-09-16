{% sv_line_anchor %}
// Full AXI4. The driver always talks to an axi4_intf instance named s_axi
// (matches the DUT's interface port for `regblock dut (.*)`). Single-beat
// driver: exercises the cpuif through the same read/write task API as the
// other cpuif test modes. For the FlatAXI4 test mode, glue assigns bridge
// the interface to the DUT's discrete s_axi_* wires.
axi4_intf #(
    .DATA_WIDTH({{exporter.cpuif.data_width}}),
    .ADDR_WIDTH({{exporter.cpuif.addr_width}}),
    .ID_WIDTH(1)
) s_axi();
axi4_driver #(
    .DATA_WIDTH({{exporter.cpuif.data_width}}),
    .ADDR_WIDTH({{exporter.cpuif.addr_width}}),
    .ID_WIDTH(1)
) cpuif (
    .clk(clk),
    .rst(rst),
    .m_axi(s_axi)
);

{% if type(cpuif).__name__.startswith("Flat") %}
{% sv_line_anchor %}
wire s_axi_awready;
wire s_axi_awvalid;
wire [0:0] s_axi_awid;
wire [{{exporter.cpuif.addr_width - 1}}:0] s_axi_awaddr;
wire [7:0] s_axi_awlen;
wire [2:0] s_axi_awsize;
wire [1:0] s_axi_awburst;
wire [2:0] s_axi_awprot;
wire s_axi_wready;
wire s_axi_wvalid;
wire [{{exporter.cpuif.data_width - 1}}:0] s_axi_wdata;
wire [{{exporter.cpuif.data_width_bytes - 1}}:0] s_axi_wstrb;
wire s_axi_wlast;
wire s_axi_bready;
wire s_axi_bvalid;
wire [0:0] s_axi_bid;
wire [1:0] s_axi_bresp;
wire s_axi_arready;
wire s_axi_arvalid;
wire [0:0] s_axi_arid;
wire [{{exporter.cpuif.addr_width - 1}}:0] s_axi_araddr;
wire [7:0] s_axi_arlen;
wire [2:0] s_axi_arsize;
wire [1:0] s_axi_arburst;
wire [2:0] s_axi_arprot;
wire s_axi_rready;
wire s_axi_rvalid;
wire [0:0] s_axi_rid;
wire [{{exporter.cpuif.data_width - 1}}:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire s_axi_rlast;
assign s_axi_awready = s_axi.AWREADY;
assign s_axi.AWVALID = s_axi_awvalid;
assign s_axi.AWID = s_axi_awid;
assign s_axi.AWADDR = s_axi_awaddr;
assign s_axi.AWLEN = s_axi_awlen;
assign s_axi.AWSIZE = s_axi_awsize;
assign s_axi.AWBURST = s_axi_awburst;
assign s_axi.AWPROT = s_axi_awprot;
assign s_axi_wready = s_axi.WREADY;
assign s_axi.WVALID = s_axi_wvalid;
assign s_axi.WDATA = s_axi_wdata;
assign s_axi.WSTRB = s_axi_wstrb;
assign s_axi.WLAST = s_axi_wlast;
assign s_axi.BREADY = s_axi_bready;
assign s_axi_bvalid = s_axi.BVALID;
assign s_axi_bid = s_axi.BID;
assign s_axi_bresp = s_axi.BRESP;
assign s_axi_arready = s_axi.ARREADY;
assign s_axi.ARVALID = s_axi_arvalid;
assign s_axi.ARID = s_axi_arid;
assign s_axi.ARADDR = s_axi_araddr;
assign s_axi.ARLEN = s_axi_arlen;
assign s_axi.ARSIZE = s_axi_arsize;
assign s_axi.ARBURST = s_axi_arburst;
assign s_axi.ARPROT = s_axi_arprot;
assign s_axi.RREADY = s_axi_rready;
assign s_axi_rvalid = s_axi.RVALID;
assign s_axi_rid = s_axi.RID;
assign s_axi_rdata = s_axi.RDATA;
assign s_axi_rresp = s_axi.RRESP;
assign s_axi_rlast = s_axi.RLAST;
{% endif %}
