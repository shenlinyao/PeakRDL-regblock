// Single-beat AXI4 master driver for the regblock test suite.
//
// Implements the same task API as the other cpuif test-mode drivers
// (reset/write/read/assert_read) using single-beat AXI4 transactions
// (AxLEN=0, AxSIZE=bus width, AxBURST=INCR, IDs tied to 0), which the
// full-AXI4 cpuif accepts as the degenerate case of a burst.
//
// Modeled on ../axi4lite/axi4lite_intf_driver.sv: mailbox-based write
// requests with independent AW/W issue processes, response listeners that
// match responses to requests in order, and randomized BREADY/RREADY.
interface axi4_driver #(
        parameter DATA_WIDTH = 32,
        parameter ADDR_WIDTH = 32,
        parameter ID_WIDTH = 1
    )(
        input wire clk,
        input wire rst,
        axi4_intf.master m_axi
    );

    timeunit 1ps;
    timeprecision 1ps;

    localparam int AXSIZE = $clog2(DATA_WIDTH/8);

    // Short-hand aliases so the body below stays close to the axi4lite driver
    logic AWREADY, AWVALID, WREADY, WVALID, BREADY, BVALID;
    logic ARREADY, ARVALID, RREADY, RVALID, RLAST;
    logic [ADDR_WIDTH-1:0] AWADDR, ARADDR;
    logic [DATA_WIDTH-1:0] WDATA, RDATA;
    logic [DATA_WIDTH/8-1:0] WSTRB;
    logic [1:0] BRESP, RRESP;

    assign AWREADY = m_axi.AWREADY;
    assign m_axi.AWVALID = AWVALID;
    assign m_axi.AWID = '0;
    assign m_axi.AWADDR = AWADDR;
    assign m_axi.AWLEN = '0;
    assign m_axi.AWSIZE = 3'(AXSIZE);
    assign m_axi.AWBURST = 2'b01; // INCR
    assign m_axi.AWPROT = '0;
    assign WREADY = m_axi.WREADY;
    assign m_axi.WVALID = WVALID;
    assign m_axi.WDATA = WDATA;
    assign m_axi.WSTRB = WSTRB;
    assign m_axi.WLAST = WVALID; // single beat: WLAST == WVALID
    assign m_axi.BREADY = BREADY;
    assign BVALID = m_axi.BVALID;
    assign BRESP = m_axi.BRESP;
    assign ARREADY = m_axi.ARREADY;
    assign m_axi.ARVALID = ARVALID;
    assign m_axi.ARID = '0;
    assign m_axi.ARADDR = ARADDR;
    assign m_axi.ARLEN = '0;
    assign m_axi.ARSIZE = 3'(AXSIZE);
    assign m_axi.ARBURST = 2'b01; // INCR
    assign m_axi.ARPROT = '0;
    assign m_axi.RREADY = RREADY;
    assign RVALID = m_axi.RVALID;
    assign RDATA = m_axi.RDATA;
    assign RRESP = m_axi.RRESP;
    assign RLAST = m_axi.RLAST;

    default clocking cb @(posedge clk);
        default input #1step output #1;
        input AWREADY;
        output AWVALID;
        output AWADDR;
        input WREADY;
        output WVALID;
        output WDATA;
        output WSTRB;
        inout BREADY;
        input BVALID;
        input BRESP;
        input ARREADY;
        output ARVALID;
        output ARADDR;
        inout RREADY;
        input RVALID;
        input RDATA;
        input RRESP;
        input RLAST;
    endclocking

    task automatic reset();
        cb.AWVALID <= '0;
        cb.AWADDR <= '0;
        cb.WVALID <= '0;
        cb.WDATA <= '0;
        cb.WSTRB <= '0;
        cb.ARVALID <= '0;
        cb.ARADDR <= '0;
    endtask

    initial forever begin
        cb.RREADY <= $urandom_range(1, 0);
        cb.BREADY <= $urandom_range(1, 0);
        @cb;
    end

    //--------------------------------------------------------------------------
    typedef struct {
        logic [1:0] bresp;
    } write_response_t;

    class write_request_t;
        mailbox #(write_response_t) response_mbx;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic [DATA_WIDTH/8-1:0] strb;
        function new();
            this.response_mbx = new();
        endfunction
    endclass

    mailbox #(write_request_t) aw_mbx = new();
    mailbox #(write_request_t) w_mbx = new();
    write_request_t write_queue[$];

    // Issue AW transfers
    initial forever begin
        write_request_t req;
        aw_mbx.get(req);
        ##0;
        repeat($urandom_range(2,0)) @cb;
        cb.AWVALID <= '1;
        cb.AWADDR <= req.addr;
        @(cb);
        while(cb.AWREADY !== 1'b1) @(cb);
        cb.AWVALID <= '0;
    end

    // Issue W transfers
    initial forever begin
        write_request_t req;
        w_mbx.get(req);
        ##0;
        repeat($urandom_range(2,0)) @cb;
        cb.WVALID <= '1;
        cb.WDATA <= req.data;
        cb.WSTRB <= req.strb;
        @(cb);
        while(cb.WREADY !== 1'b1) @(cb);
        cb.WVALID <= '0;
        cb.WSTRB <= '0;
    end

    // Listen for B responses
    initial forever begin
        @cb;
        while(rst || !(cb.BREADY === 1'b1 && cb.BVALID === 1'b1)) @cb;
        if(write_queue.size() != 0) begin
            write_request_t req;
            write_response_t resp;
            req = write_queue.pop_front();
            resp.bresp = cb.BRESP;
            req.response_mbx.put(resp);
        end else begin
            $error("Got unmatched write response");
        end
    end

    task automatic write(logic [ADDR_WIDTH-1:0] addr, logic [DATA_WIDTH-1:0] data, input logic [DATA_WIDTH/8-1:0] strb = {DATA_WIDTH{1'b1}}, logic expects_err = 1'b0);
        write_request_t req;
        write_response_t resp;

        req = new();
        req.addr = addr;
        req.data = data;
        req.strb = strb;

        aw_mbx.put(req);
        w_mbx.put(req);
        write_queue.push_back(req);

        // Wait for response
        req.response_mbx.get(resp);
        assert(!$isunknown(resp.bresp)) else $error("Write to 0x%0x returned X's on BRESP", addr);
        assert((resp.bresp==2'b10) == expects_err) else $error("Error write response to 0x%x returned 0x%x. Expected 0x%x", addr, (resp.bresp==2'b10), expects_err);
    endtask

    //--------------------------------------------------------------------------
    typedef struct {
        logic [DATA_WIDTH-1: 0] rdata;
        logic [1:0] rresp;
    } read_response_t;

    class read_request_t;
        mailbox #(read_response_t) response_mbx;
        function new();
            this.response_mbx = new();
        endfunction
    endclass

    semaphore txn_ar_mutex = new(1);
    read_request_t read_queue[$];

    // Listen for R responses
    initial forever begin
        @cb;
        while(rst || !(cb.RREADY === 1'b1 && cb.RVALID === 1'b1)) @cb;
        assert(cb.RLAST === 1'b1) else $error("RVALID without RLAST on single-beat read");
        if(read_queue.size() != 0) begin
            read_request_t req;
            read_response_t resp;
            req = read_queue.pop_front();
            resp.rdata = cb.RDATA;
            resp.rresp = cb.RRESP;
            req.response_mbx.put(resp);
        end else begin
            $error("Got unmatched read response");
        end
    end

    task automatic read(logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data, input logic expects_err = 1'b0);
        read_request_t req;
        read_response_t resp;

        txn_ar_mutex.get();
        // Issue read request
        ##0;
        cb.ARVALID <= '1;
        cb.ARADDR <= addr;
        @(cb);
        while(cb.ARREADY !== 1'b1) @(cb);
        cb.ARVALID <= '0;

        // Push new request into queue
        req = new();
        read_queue.push_back(req);
        txn_ar_mutex.put();

        // Wait for response
        req.response_mbx.get(resp);

        assert(!$isunknown(resp.rdata)) else $error("Read from 0x%0x returned X's on RDATA", addr);
        assert(!$isunknown(resp.rresp)) else $error("Read from 0x%0x returned X's on RRESP", addr);
        assert((resp.rresp == 2'b10) == expects_err) else $error("Error read response from 0x%x returned 0x%x. Expected 0x%x", addr, (resp.rresp == 2'b10), expects_err);
        data = resp.rdata;
    endtask

    task automatic assert_read(logic [ADDR_WIDTH-1:0] addr, logic [DATA_WIDTH-1:0] expected_data, logic [DATA_WIDTH-1:0] mask = {DATA_WIDTH{1'b1}}, input logic expects_err = 1'b0);
        logic [DATA_WIDTH-1:0] data;
        read(addr, data, expects_err);
        data &= mask;
        assert(data == expected_data) else $error("Read from 0x%x returned 0x%x. Expected 0x%x", addr, data, expected_data);
    endtask
endinterface
