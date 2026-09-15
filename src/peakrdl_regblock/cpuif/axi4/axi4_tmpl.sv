//==========================================================================
// Full AXI4 slave CPU interface with burst support.
//
// Decomposes AXI4 bursts (INCR/FIXED/WRAP, narrow transfers) into
// sequential single-beat transfers on the internal CPUIF protocol.
// One burst per direction at a time (AWREADY/ARREADY low while busy);
// read and write bursts may be active concurrently.
//==========================================================================

{%- set AW = cpuif.addr_width %}
{%- set DW = cpuif.data_width %}
{%- set NB = cpuif.data_width_bytes %}
{%- set LG = cpuif.bus_bytes_lg %}
{%- set MO = cpuif.max_outstanding %}
{%- set RB = cpuif.resp_buffer_size %}

// AXI4 encodings
localparam logic [1:0] AXI4_BURST_FIXED = 2'b00;
localparam logic [1:0] AXI4_BURST_WRAP  = 2'b10;
localparam logic [1:0] AXI4_RESP_OKAY   = 2'b00;
localparam logic [1:0] AXI4_RESP_SLVERR = 2'b10;

//--------------------------------------------------------------------------
// Per-beat next-address computation.
// WRAP span (total) is guaranteed a power of two by the legality check.
//--------------------------------------------------------------------------
function automatic logic [{{AW-1}}:0] axi4_next_beat_addr(
    input logic [{{AW-1}}:0] cur_addr,
    input logic [7:0] len,
    input logic [2:0] size,
    input logic [1:0] burst
);
    logic [31:0] step, total, incr;
    begin
        step  = 32'd1 << size;
        total = (32'(len) + 32'd1) << size;
        incr  = 32'(cur_addr) + step;
        if(burst == AXI4_BURST_FIXED) begin
            return cur_addr;
        end else if(burst == AXI4_BURST_WRAP && ((incr & (total - 32'd1)) == 32'd0)) begin
            return {{AW}}'(incr - total);
        end else begin
            return {{AW}}'(incr);
        end
    end
endfunction

//--------------------------------------------------------------------------
// Burst legality: size must not exceed the bus width, burst type must be
// valid, WRAP length must be 2/4/8/16 beats.
//--------------------------------------------------------------------------
function automatic logic axi4_burst_illegal(
    input logic [7:0] len,
    input logic [2:0] size,
    input logic [1:0] burst
);
    begin
        if(size > 3'd{{LG}}) return 1'b1;
        if(burst == 2'b11) return 1'b1;
        if(burst == AXI4_BURST_WRAP &&
           !(len == 8'd1 || len == 8'd3 || len == 8'd7 || len == 8'd15)) return 1'b1;
        return 1'b0;
    end
endfunction

//--------------------------------------------------------------------------
// Write engine: AW accept -> per-beat W consumption -> B response
//--------------------------------------------------------------------------
enum logic [2:0] {AXI4_W_IDLE, AXI4_W_RUN, AXI4_W_WAIT_ACK, AXI4_W_DISCARD, AXI4_W_RESP} axi4_wstate;
logic [ID_WIDTH-1:0] axi4_wid;
logic [{{AW-1}}:0] axi4_waddr;
logic [7:0] axi4_wlen;
logic [2:0] axi4_wsize;
logic [1:0] axi4_wburst;
logic [8:0] axi4_wbeats;
logic axi4_werr;

//--------------------------------------------------------------------------
// Read engine: AR accept -> pipelined beat issue -> response FIFO -> R channel
//--------------------------------------------------------------------------
enum logic [1:0] {AXI4_R_IDLE, AXI4_R_ACTIVE, AXI4_R_ERR} axi4_rstate;
logic [ID_WIDTH-1:0] axi4_rid;
logic [{{AW-1}}:0] axi4_raddr;
logic [7:0] axi4_rlen;
logic [2:0] axi4_rsize;
logic [1:0] axi4_rburst;
logic [8:0] axi4_r_issued;
logic [8:0] axi4_r_returned;
logic [8:0] axi4_r_errcnt;
// Unreturned read beats (dispatched but not yet consumed by the R channel).
// Throttles beat issue so the response FIFO can never overflow, independent
// of the core's read ack latency (which may be 0 for internal registers).
logic [{{clog2(MO+1)-1}}:0] axi4_rd_in_flight;

// Read response FIFO. Depth {{RB}} >= max outstanding {{MO}}: cannot overflow.
logic [{{DW-1}}:0] axi4_rfifo_data[{{roundup_pow2(RB)}}];
logic axi4_rfifo_err[{{roundup_pow2(RB)}}];
{%- if not is_pow2(RB) %}
// FIFO arrays are intentionally padded to the next power of two despite only
// requiring {{RB}} entries, to avoid tool quirks with non-power-of-2 arrays.
{%- endif %}
logic [{{clog2(RB)}}:0] axi4_rfifo_wptr;
logic [{{clog2(RB)}}:0] axi4_rfifo_rptr;

//--------------------------------------------------------------------------
// Round-robin arbiter for the single internal request bus
//--------------------------------------------------------------------------
logic axi4_arb_prev_rd;
logic axi4_rd_wants;
logic axi4_wr_wants;
logic axi4_grant_rd;
logic axi4_grant_wr;
logic axi4_dispatch_rd;
logic axi4_dispatch_wr;

always_comb begin
    axi4_rd_wants = (axi4_rstate == AXI4_R_ACTIVE)
                    && (axi4_r_issued <= {1'b0, axi4_rlen})
                    && (axi4_rd_in_flight < {{clog2(MO+1)}}'d{{MO}});
    axi4_wr_wants = (axi4_wstate == AXI4_W_RUN) && {{cpuif.signal("wvalid")}};

    axi4_grant_rd = axi4_rd_wants && (!axi4_wr_wants || !axi4_arb_prev_rd);
    axi4_grant_wr = axi4_wr_wants && (!axi4_rd_wants || axi4_arb_prev_rd);

    axi4_dispatch_rd = axi4_grant_rd && !cpuif_req_stall_rd;
    axi4_dispatch_wr = axi4_grant_wr && !cpuif_req_stall_wr;
end

//--------------------------------------------------------------------------
// Internal request bus drive
//--------------------------------------------------------------------------
always_comb begin
    cpuif_req = '0;
    cpuif_req_is_wr = '0;
    cpuif_addr = '0;
    cpuif_wr_data = {{cpuif.signal("wdata")}};
    for(int i=0; i<{{NB}}; i++) begin
        cpuif_wr_biten[i*8 +: 8] = {8{ {{cpuif.signal("wstrb")}}[i] }};
    end

    if(axi4_grant_wr) begin
        cpuif_req = '1;
        cpuif_req_is_wr = '1;
        {%- if NB == 1 %}
        cpuif_addr = axi4_waddr;
        {%- else %}
        cpuif_addr = {axi4_waddr[{{AW-1}}:{{LG}}], {{LG}}'b0};
        {%- endif %}
    end else if(axi4_grant_rd) begin
        cpuif_req = '1;
        {%- if NB == 1 %}
        cpuif_addr = axi4_raddr;
        {%- else %}
        cpuif_addr = {axi4_raddr[{{AW-1}}:{{LG}}], {{LG}}'b0};
        {%- endif %}
    end
end

//--------------------------------------------------------------------------
// Write engine sequential logic
//--------------------------------------------------------------------------
always_ff {{get_always_ff_event(cpuif.reset)}} begin
    if({{get_resetsignal(cpuif.reset)}}) begin
        axi4_wstate <= AXI4_W_IDLE;
        axi4_wid <= '0;
        axi4_waddr <= '0;
        axi4_wlen <= '0;
        axi4_wsize <= '0;
        axi4_wburst <= '0;
        axi4_wbeats <= '0;
        axi4_werr <= '0;
        axi4_arb_prev_rd <= '0;
    end else begin
        // Free-running write error fold. cpuif_wr_ack pulses at most once per
        // cycle and always belongs to this burst (writes are serialized,
        // at most one un-acked write beat exists).
        if(cpuif_wr_ack && cpuif_wr_err) axi4_werr <= '1;

        if(axi4_dispatch_rd) axi4_arb_prev_rd <= '1;
        else if(axi4_dispatch_wr) axi4_arb_prev_rd <= '0;

        case(axi4_wstate)
            AXI4_W_IDLE: begin
                if({{cpuif.signal("awvalid")}}) begin
                    axi4_wid <= {{cpuif.signal("awid")}};
                    axi4_waddr <= {{cpuif.signal("awaddr")}};
                    axi4_wlen <= {{cpuif.signal("awlen")}};
                    axi4_wsize <= {{cpuif.signal("awsize")}};
                    axi4_wburst <= {{cpuif.signal("awburst")}};
                    axi4_wbeats <= '0;
                    if(axi4_burst_illegal({{cpuif.signal("awlen")}}, {{cpuif.signal("awsize")}}, {{cpuif.signal("awburst")}})) begin
                        axi4_werr <= '1;
                        axi4_wstate <= AXI4_W_DISCARD;
                    end else begin
                        axi4_werr <= '0;
                        axi4_wstate <= AXI4_W_RUN;
                    end
                end
            end
            AXI4_W_RUN: begin
                if(axi4_dispatch_wr) begin
                    axi4_waddr <= axi4_next_beat_addr(axi4_waddr, axi4_wlen, axi4_wsize, axi4_wburst);
                    axi4_wbeats <= axi4_wbeats + 1'b1;
                    if({{cpuif.signal("wlast")}}) begin
                        // Internal writes ack same-cycle; external writes ack later
                        if(cpuif_wr_ack) axi4_wstate <= AXI4_W_RESP;
                        else axi4_wstate <= AXI4_W_WAIT_ACK;
                    end
                end
            end
            AXI4_W_WAIT_ACK: begin
                if(cpuif_wr_ack) axi4_wstate <= AXI4_W_RESP;
            end
            AXI4_W_DISCARD: begin
                // Swallow W beats of an illegal burst without touching the core
                if({{cpuif.signal("wvalid")}} && {{cpuif.signal("wlast")}}) axi4_wstate <= AXI4_W_RESP;
            end
            AXI4_W_RESP: begin
                if({{cpuif.signal("bready")}}) axi4_wstate <= AXI4_W_IDLE;
            end
            default: axi4_wstate <= AXI4_W_IDLE;
        endcase
    end
end

always_comb begin
    {{cpuif.signal("awready")}} = (axi4_wstate == AXI4_W_IDLE);
    {{cpuif.signal("wready")}} = (axi4_wstate == AXI4_W_RUN) ? !cpuif_req_stall_wr && axi4_grant_wr
                               : (axi4_wstate == AXI4_W_DISCARD);
    {{cpuif.signal("bvalid")}} = (axi4_wstate == AXI4_W_RESP);
    {{cpuif.signal("bid")}} = axi4_wid;
    {{cpuif.signal("bresp")}} = axi4_werr ? AXI4_RESP_SLVERR : AXI4_RESP_OKAY;
end

//--------------------------------------------------------------------------
// Read engine sequential logic
//--------------------------------------------------------------------------
always_ff {{get_always_ff_event(cpuif.reset)}} begin
    if({{get_resetsignal(cpuif.reset)}}) begin
        axi4_rstate <= AXI4_R_IDLE;
        axi4_rid <= '0;
        axi4_raddr <= '0;
        axi4_rlen <= '0;
        axi4_rsize <= '0;
        axi4_rburst <= '0;
        axi4_r_issued <= '0;
        axi4_r_returned <= '0;
        axi4_r_errcnt <= '0;
        axi4_rd_in_flight <= '0;
        for(int i=0; i<{{RB}}; i++) begin
            axi4_rfifo_data[i] <= '0;
            axi4_rfifo_err[i] <= '0;
        end
        axi4_rfifo_wptr <= '0;
        axi4_rfifo_rptr <= '0;
    end else begin
        case(axi4_rstate)
            AXI4_R_IDLE: begin
                if({{cpuif.signal("arvalid")}}) begin
                    axi4_rid <= {{cpuif.signal("arid")}};
                    axi4_raddr <= {{cpuif.signal("araddr")}};
                    axi4_rlen <= {{cpuif.signal("arlen")}};
                    axi4_rsize <= {{cpuif.signal("arsize")}};
                    axi4_rburst <= {{cpuif.signal("arburst")}};
                    axi4_r_issued <= '0;
                    axi4_r_returned <= '0;
                    axi4_r_errcnt <= '0;
                    if(axi4_burst_illegal({{cpuif.signal("arlen")}}, {{cpuif.signal("arsize")}}, {{cpuif.signal("arburst")}})) begin
                        axi4_rstate <= AXI4_R_ERR;
                    end else begin
                        axi4_rstate <= AXI4_R_ACTIVE;
                    end
                end
            end
            AXI4_R_ACTIVE: begin
                if(axi4_dispatch_rd) begin
                    axi4_raddr <= axi4_next_beat_addr(axi4_raddr, axi4_rlen, axi4_rsize, axi4_rburst);
                    axi4_r_issued <= axi4_r_issued + 1'b1;
                end
                if({{cpuif.signal("rvalid")}} && {{cpuif.signal("rready")}}) begin
                    axi4_r_returned <= axi4_r_returned + 1'b1;
                    if(axi4_r_returned == {1'b0, axi4_rlen}) axi4_rstate <= AXI4_R_IDLE;
                end
            end
            AXI4_R_ERR: begin
                // Stream len+1 SLVERR beats without touching the core
                if({{cpuif.signal("rvalid")}} && {{cpuif.signal("rready")}}) begin
                    axi4_r_errcnt <= axi4_r_errcnt + 1'b1;
                    if(axi4_r_errcnt == {1'b0, axi4_rlen}) axi4_rstate <= AXI4_R_IDLE;
                end
            end
            default: axi4_rstate <= AXI4_R_IDLE;
        endcase

        // Unreturned-beat accounting: dispatch increments, R-channel pop decrements
        if(axi4_dispatch_rd && !(axi4_rstate == AXI4_R_ACTIVE && {{cpuif.signal("rvalid")}} && {{cpuif.signal("rready")}})) begin
            axi4_rd_in_flight <= axi4_rd_in_flight + 1'b1;
        end else if(!axi4_dispatch_rd && axi4_rstate == AXI4_R_ACTIVE && {{cpuif.signal("rvalid")}} && {{cpuif.signal("rready")}}) begin
            axi4_rd_in_flight <= axi4_rd_in_flight - 1'b1;
        end

        // Response FIFO push: read latency is variable for external components
        if(cpuif_rd_ack) begin
            axi4_rfifo_data[axi4_rfifo_wptr[{{clog2(RB)-1}}:0]] <= cpuif_rd_data;
            axi4_rfifo_err[axi4_rfifo_wptr[{{clog2(RB)-1}}:0]] <= cpuif_rd_err;
            {%- if is_pow2(RB) %}
            axi4_rfifo_wptr <= axi4_rfifo_wptr + 1'b1;
            {%- else %}
            if(axi4_rfifo_wptr[{{clog2(RB)-1}}:0] == {{RB-1}}) begin
                axi4_rfifo_wptr[{{clog2(RB)-1}}:0] <= '0;
                axi4_rfifo_wptr[{{clog2(RB)}}] <= ~axi4_rfifo_wptr[{{clog2(RB)}}];
            end else begin
                axi4_rfifo_wptr[{{clog2(RB)-1}}:0] <= axi4_rfifo_wptr[{{clog2(RB)-1}}:0] + 1'b1;
            end
            {%- endif %}
        end

        // Response FIFO pop
        if(axi4_rstate == AXI4_R_ACTIVE && {{cpuif.signal("rvalid")}} && {{cpuif.signal("rready")}}) begin
            {%- if is_pow2(RB) %}
            axi4_rfifo_rptr <= axi4_rfifo_rptr + 1'b1;
            {%- else %}
            if(axi4_rfifo_rptr[{{clog2(RB)-1}}:0] == {{RB-1}}) begin
                axi4_rfifo_rptr[{{clog2(RB)-1}}:0] <= '0;
                axi4_rfifo_rptr[{{clog2(RB)}}] <= ~axi4_rfifo_rptr[{{clog2(RB)}}];
            end else begin
                axi4_rfifo_rptr[{{clog2(RB)-1}}:0] <= axi4_rfifo_rptr[{{clog2(RB)-1}}:0] + 1'b1;
            end
            {%- endif %}
        end
    end
end

always_comb begin
    {{cpuif.signal("arready")}} = (axi4_rstate == AXI4_R_IDLE);
    {{cpuif.signal("rid")}} = axi4_rid;
    if(axi4_rstate == AXI4_R_ERR) begin
        {{cpuif.signal("rvalid")}} = '1;
        {{cpuif.signal("rdata")}} = '0;
        {{cpuif.signal("rresp")}} = AXI4_RESP_SLVERR;
        {{cpuif.signal("rlast")}} = (axi4_r_errcnt == {1'b0, axi4_rlen});
    end else begin
        {{cpuif.signal("rvalid")}} = (axi4_rstate == AXI4_R_ACTIVE)
                                     && (axi4_rfifo_rptr != axi4_rfifo_wptr);
        {{cpuif.signal("rdata")}} = axi4_rfifo_data[axi4_rfifo_rptr[{{clog2(RB)-1}}:0]];
        {{cpuif.signal("rresp")}} = axi4_rfifo_err[axi4_rfifo_rptr[{{clog2(RB)-1}}:0]]
                                    ? AXI4_RESP_SLVERR : AXI4_RESP_OKAY;
        {{cpuif.signal("rlast")}} = (axi4_r_returned == {1'b0, axi4_rlen});
    end
end

//--------------------------------------------------------------------------
// Protocol consistency checks (simulation only)
//--------------------------------------------------------------------------
`ifndef SYNTHESIS
always_ff {{get_always_ff_event(cpuif.reset)}} begin
    if(!{{get_resetsignal(cpuif.reset)}}) begin
        if(axi4_dispatch_wr) begin
            assert_wlast_position: assert({{cpuif.signal("wlast")}} == (axi4_wbeats == {1'b0, axi4_wlen}))
                else $error("AXI4 WLAST assertion does not match AWLEN: beats=%0d awlen=%0d", axi4_wbeats, axi4_wlen);
        end
    end
end
`endif
