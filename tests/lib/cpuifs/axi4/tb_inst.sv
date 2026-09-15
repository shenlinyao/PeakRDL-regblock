{% sv_line_anchor %}
// Full AXI4 (flat s_axi_* ports). Wire names match the DUT port names, so
// `regblock dut (.*)` connects them. Single-beat driver: exercises the cpuif
// through the same read/write task API as the other cpuif test modes.
logic s_axi_awready;
logic s_axi_awvalid;
logic [0:0] s_axi_awid;
logic [{{exporter.cpuif.addr_width - 1}}:0] s_axi_awaddr;
logic [7:0] s_axi_awlen;
logic [2:0] s_axi_awsize;
logic [1:0] s_axi_awburst;
logic [2:0] s_axi_awprot;
logic s_axi_wready;
logic s_axi_wvalid;
logic [{{exporter.cpuif.data_width - 1}}:0] s_axi_wdata;
logic [{{exporter.cpuif.data_width_bytes - 1}}:0] s_axi_wstrb;
logic s_axi_wlast;
logic s_axi_bready;
logic s_axi_bvalid;
logic [0:0] s_axi_bid;
logic [1:0] s_axi_bresp;
logic s_axi_arready;
logic s_axi_arvalid;
logic [0:0] s_axi_arid;
logic [{{exporter.cpuif.addr_width - 1}}:0] s_axi_araddr;
logic [7:0] s_axi_arlen;
logic [2:0] s_axi_arsize;
logic [1:0] s_axi_arburst;
logic [2:0] s_axi_arprot;
logic s_axi_rready;
logic s_axi_rvalid;
logic [0:0] s_axi_rid;
logic [{{exporter.cpuif.data_width - 1}}:0] s_axi_rdata;
logic [1:0] s_axi_rresp;
logic s_axi_rlast;

{% sv_line_anchor %}
axi4_driver #(
    .DATA_WIDTH({{exporter.cpuif.data_width}}),
    .ADDR_WIDTH({{exporter.cpuif.addr_width}}),
    .ID_WIDTH(1)
) cpuif (
    .clk(clk),
    .rst(rst),
    .s_axi_awready(s_axi_awready),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_wready(s_axi_wready),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_bready(s_axi_bready),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_arready(s_axi_arready),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_rready(s_axi_rready),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast)
);
