// Modified by Laurentiu Cristian Duca, 2025/08

/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/
/*
  * AHB-lite 1:N splitter
  * If this splitter is at the top of the busfabric (i.e. its master is a true master),
  * tie src_hready_resp across to src_hready.
  *
  * It is up to the system implementer to *ensure that the address mapped ranges
  *  are mutually exclusive*.
  */

// TODO: burst support

module ahbl_splitter #(
    parameter N_PORTS   = 2,
    //parameter W_ADDR = 32,
    //parameter W_DATA = 32,
    parameter ADDR_MAP  = 64'h20000000_00000000,
    parameter ADDR_MASK = 64'hf0000000_f0000000,
    parameter CONN_MASK = {N_PORTS{1'b1}},
    `include "hazard3_config.vh"
) (
    // Global signals
    input wire clk,
    input wire rst_n,

    input wire [W_ADDR-1:0] src_d_pc,
    input wire [W_DATA-1:0] src_hartid,

    // From master; functions as slave port
    input  wire              src_hready,
    output wire              src_hready_resp,
    output wire              src_hresp,
    input  wire [W_ADDR-1:0] src_haddr,
    input  wire              src_hwrite,
    input  wire [       1:0] src_htrans,
    input  wire [       2:0] src_hsize,
    input  wire [       2:0] src_hburst,
    input  wire [       3:0] src_hprot,
    input  wire              src_hmastlock,
    input  wire [W_DATA-1:0] src_hwdata,
    output wire [W_DATA-1:0] src_hrdata,
    // exlusive access signaling
    input  wire              src_hexcl,
    input  wire [       7:0] src_hmaster,
    output wire              src_hexokay,

    // To slaves; function as master ports
    output wire [       N_PORTS-1:0] dst_hready,
    input  wire [       N_PORTS-1:0] dst_hready_resp,
    input  wire [       N_PORTS-1:0] dst_hresp,
    output wire [N_PORTS*W_ADDR-1:0] dst_haddr,
    output wire [       N_PORTS-1:0] dst_hwrite,
    output reg  [     N_PORTS*2-1:0] dst_htrans,
    output wire [     N_PORTS*3-1:0] dst_hsize,
    output wire [     N_PORTS*3-1:0] dst_hburst,
    output wire [     N_PORTS*4-1:0] dst_hprot,
    output wire [       N_PORTS-1:0] dst_hmastlock,
    output wire [N_PORTS*W_DATA-1:0] dst_hwdata,
    input  wire [N_PORTS*W_DATA-1:0] dst_hrdata,
    output wire [N_PORTS*W_ADDR-1:0] dst_d_pc,
    output wire [N_PORTS*W_DATA-1:0] dst_hartid,
    // exlusive access signaling
    output wire [       N_PORTS-1:0] dst_hexcl,
    output wire [     N_PORTS*8-1:0] dst_hmaster,
    input  wire [       N_PORTS-1:0] dst_hexokay,
    output reg  [       N_PORTS-1:0] slave_sel_d
);

    localparam HTRANS_IDLE = 2'b00;

    integer i;

    // Address decode

    reg [N_PORTS-1:0] slave_sel_a_nomask;
    reg [N_PORTS-1:0] slave_sel_a;
    reg decode_err_a;

    always @(*) begin
        if (src_htrans == HTRANS_IDLE) begin
            slave_sel_a_nomask = {N_PORTS{1'b0}};
            slave_sel_a = {N_PORTS{1'b0}};
            decode_err_a = 1'b0;
        end else begin
            for (i = 0; i < N_PORTS; i = i + 1) begin
                //slave_sel_a_nomask[i] = !((src_haddr ^ ADDR_MAP[i * W_ADDR +: W_ADDR])
                //	& ADDR_MASK[i * W_ADDR +: W_ADDR]);
                // laur
                slave_sel_a_nomask[i] = ((src_haddr & ADDR_MASK[i * W_ADDR +: W_ADDR])
                                == ADDR_MAP[i * W_ADDR +: W_ADDR]);
            end
            slave_sel_a  = slave_sel_a_nomask & CONN_MASK;
            decode_err_a = !slave_sel_a_nomask;
        end
    end

    // Address-phase passthrough
    // Be lazy and don't blank out signals to non-selected slaves,
    // except for HTRANS, which must be gated off to stop spurious transfer.
    // Costs transitions, but saves gates.

    assign dst_haddr     = {N_PORTS{src_haddr}};
    assign dst_hwrite    = {N_PORTS{src_hwrite}};
    assign dst_hsize     = {N_PORTS{src_hsize}};
    assign dst_hburst    = {N_PORTS{src_hburst}};
    assign dst_hprot     = {N_PORTS{src_hprot}};
    assign dst_hmastlock = {N_PORTS{src_hmastlock}};
    assign dst_hexcl     = {N_PORTS{src_hexcl}};
    assign dst_hmaster   = {N_PORTS{src_hmaster}};
    assign dst_d_pc      = {N_PORTS{src_d_pc}};
    assign dst_hartid    = {N_PORTS{src_hartid}};

    always @(*) begin
        for (i = 0; i < N_PORTS; i = i + 1) begin
            dst_htrans[i*2+:2] = slave_sel_a[i] ? src_htrans : HTRANS_IDLE;
        end
    end

    // AHB state machine

    reg decode_err_d;
    reg err_ph1;
    reg waswr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_d <= {N_PORTS{1'b0}};
            decode_err_d <= 1'b0;
            err_ph1 <= 1'b0;
            waswr <= 0;
        end else begin
            if (src_hready) begin
                slave_sel_d  <= slave_sel_a;
                decode_err_d <= decode_err_a;
            end

            if (decode_err_d) begin
                err_ph1 <= !err_ph1;
            end else begin
                err_ph1 <= 1'b0;
            end
        end
    end

    // Data-phase passthrough

    assign dst_hwdata = {N_PORTS{src_hwdata}};
    assign dst_hready = {N_PORTS{src_hready}};  // this triggers a new op in arbiter

    onehot_mux #(
        .N_INPUTS(N_PORTS),
        .W_INPUT (W_DATA)
    ) hrdata_mux (
        .in (dst_hrdata),
        .sel(slave_sel_d),
        .out(src_hrdata)
    );

    // We want to avoid any combinatorial paths from htrans->hready
    // both for timing closure reasons, and to avoid loops with poorly
    // behaved masters.
    // One rule to avoid this is to *only use data-phase state for muxing*

    assign src_hready_resp = (!slave_sel_d && (err_ph1 || !decode_err_d)) ||
	|(slave_sel_d & dst_hready_resp);
    assign src_hresp = decode_err_d || |(slave_sel_d & dst_hresp);
    assign src_hexokay = |(slave_sel_d & dst_hexokay);

`ifdef SIM_MODE
`ifdef dbgstart
    integer f;
    reg opened = 0, closed = 0;
    reg [31:0] timecnt = 0;
    reg [31:0] j = 0, li = 0;
    reg [31:0] osrc_haddr = 0, odst_hrdata = 0;
    reg osrc_hready = 0, osrc_hwrite = 0;
    reg [1:0] osrc_htrans = 0;
    reg [31:0] cntidle = 0, tf = 41015340, ts = 25159820;
    always @(posedge clk) begin
`ifdef dbgdhrystone
        if ($time >= ts && $time <= tf) begin
            if (slave_sel_d == 0) cntidle <= cntidle + 1;
            if ($time == ts) $display("ts start ");
            if ($time == tf) $display("tf end ");
        end
        if ($time == tf) $display("cntidle=%d tot=%d", cntidle, (tf - ts) / 10);
`endif
`ifdef dbgsclr
        if ($past(src_hwrite) && j < 30)  // && $past(src_haddr == 32'h4000400c))
            $display(
                "past wr h%1x psrc_haddr=%x src_hwdata=%x src/dst_hready_resp=%x/%x slave_sel_d=%x %8d",
                src_hartid,
                $past(
                    src_haddr
                ),
                src_hwdata,
                src_hready_resp,
                dst_hready_resp,
                slave_sel_d,
                $time
            );
`endif
        if(/*j < 20 &&*/ src_hready && 
        (osrc_haddr!= src_haddr || osrc_htrans != src_htrans ||//odst_hrdata[W_DATA-1:0] != dst_hrdata[W_DATA-1:0] || 
            osrc_hready != src_hready || osrc_hwrite != src_hwrite)) begin
            j <= j + 1;
            if (src_d_pc >= pc_trace_start && src_d_pc <= pc_trace_stop) li <= li + 1;
            osrc_hwrite <= src_hwrite;
            osrc_hready <= src_hready;
            osrc_haddr <= src_haddr;
            odst_hrdata[W_DATA-1:0] <= dst_hrdata[W_DATA-1:0];
            osrc_htrans <= src_htrans;
            if (j < 20 || (src_d_pc >= pc_trace_start && src_d_pc <= pc_trace_stop && li < 20))
                $display(
                    "h%1x src_d_pc=%x hartid=%1x src_haddr=%x,o=%x src_hready=%x,o=%x dst_hrdata=,%x src_hrdata=%x src_hwrite=%x,o=%x,%x,excl=%x slave_sel_a,d=%x,%x src_hready_resp=%1x,ok=%1x %08d",
                    src_hartid,
                    src_d_pc,
                    src_hartid,
                    src_haddr,
                    osrc_haddr,
                    src_hready,
                    osrc_hready,
                    dst_hrdata[W_DATA-1:0],
                    src_hrdata,
                    src_hwrite,
                    osrc_hwrite,
                    src_hwdata,
                    src_hexcl,
                    slave_sel_a,
                    slave_sel_d,
                    src_hready_resp,
                    src_hexokay,
                    $time
                );
            if (!closed && src_haddr > 0)
                $fwrite(
                    f,
                    "pc=%x src_haddr=%x,o=%x src_hready=%x,o=%x src_hrdata=%x src_hwrite=%x,o=%x src_hwdata=%x src_hready_resp=%x\n",
                    src_d_pc,
                    src_haddr,
                    osrc_haddr,
                    src_hready,
                    osrc_hready,
                    src_hrdata,
                    src_hwrite,
                    osrc_hwrite,
                    (src_hwrite | osrc_hwrite) ? src_hwdata : 0,
                    src_hready_resp
                );
        end
        if (timecnt > 40000000) begin
            closed <= 1;
            $fclose(f);
            //$finish();
        end
        timecnt <= timecnt + 1;
    end

    always @(posedge clk) begin
        if (!opened) begin
            opened = 1;
            f = $fopen("fout", "w");
            if (f == 0) begin
                $display("ERROR: f not opened");
                $finish;
            end
        end
    end
`endif
`endif

endmodule
