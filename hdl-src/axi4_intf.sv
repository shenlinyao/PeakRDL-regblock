interface axi4_intf #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH = 1
);
    logic AWREADY;
    logic AWVALID;
    logic [ID_WIDTH-1:0] AWID;
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [7:0] AWLEN;
    logic [2:0] AWSIZE;
    logic [1:0] AWBURST;
    logic [2:0] AWPROT;

    logic WREADY;
    logic WVALID;
    logic [DATA_WIDTH-1:0] WDATA;
    logic [DATA_WIDTH/8-1:0] WSTRB;
    logic WLAST;

    logic BREADY;
    logic BVALID;
    logic [ID_WIDTH-1:0] BID;
    logic [1:0] BRESP;

    logic ARREADY;
    logic ARVALID;
    logic [ID_WIDTH-1:0] ARID;
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [7:0] ARLEN;
    logic [2:0] ARSIZE;
    logic [1:0] ARBURST;
    logic [2:0] ARPROT;

    logic RREADY;
    logic RVALID;
    logic [ID_WIDTH-1:0] RID;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0] RRESP;
    logic RLAST;

    modport master (
        input AWREADY,
        output AWVALID,
        output AWID,
        output AWADDR,
        output AWLEN,
        output AWSIZE,
        output AWBURST,
        output AWPROT,

        input WREADY,
        output WVALID,
        output WDATA,
        output WSTRB,
        output WLAST,

        output BREADY,
        input BVALID,
        input BID,
        input BRESP,

        input ARREADY,
        output ARVALID,
        output ARID,
        output ARADDR,
        output ARLEN,
        output ARSIZE,
        output ARBURST,
        output ARPROT,

        output RREADY,
        input RVALID,
        input RID,
        input RDATA,
        input RRESP,
        input RLAST
    );

    modport slave (
        output AWREADY,
        input AWVALID,
        input AWID,
        input AWADDR,
        input AWLEN,
        input AWSIZE,
        input AWBURST,
        input AWPROT,

        output WREADY,
        input WVALID,
        input WDATA,
        input WSTRB,
        input WLAST,

        input BREADY,
        output BVALID,
        output BID,
        output BRESP,

        output ARREADY,
        input ARVALID,
        input ARID,
        input ARADDR,
        input ARLEN,
        input ARSIZE,
        input ARBURST,
        input ARPROT,

        input RREADY,
        output RVALID,
        output RID,
        output RDATA,
        output RRESP,
        output RLAST
    );
endinterface
