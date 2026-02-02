/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018-2020 Luke Wren                                  *
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

// AHB-lite to synchronous SRAM adapter with no wait states. Uses a write
// buffer with a write-to-read forwarding path to handle SRAM address
// collisions caused by misalignment of AHBL write address and write data.
//
// Optionally, the write buffer can be removed to save a small amount of
// logic. The adapter will then insert one wait state on write->read pairs.

module ahb_sync_sram #(
    //parameter W_DATA = 32,
    //parameter W_ADDR = 32,
    parameter DEPTH = 1 << 11,
    parameter HAS_WRITE_BUFFER = 1,
    parameter PRELOAD_FILE = "",
    parameter W_MEMOP = 5,
    `include "hazard3_config.vh"
) (
    // Globals
    input wire clk,
    input wire rst_n,
    input wire clk_sdram,

    input wire [W_ADDR-1:0] d_pc,
    input wire [W_DATA-1:0] hartid,
    output wire w_init_done,

    // AHB lite slave interface
    output wire              ahbls_hready_resp,
    input  wire              ahbls_hready,
    output wire              ahbls_hresp,
    input  wire [W_ADDR-1:0] ahbls_haddr,
    input  wire              ahbls_hwrite,
    input  wire [       1:0] ahbls_htrans,
    input  wire [       2:0] ahbls_hsize,
    input  wire [       2:0] ahbls_hburst,
    input  wire [       3:0] ahbls_hprot,
    input  wire              ahbls_hmastlock,
    input  wire [W_DATA-1:0] ahbls_hwdata,
    output wire [W_DATA-1:0] ahbls_hrdata,
    // exclusive access signaling
    input  wire              ahbls_hexcl,
    input  wire [       7:0] ahbls_hmaster,
    output wire              ahbls_hexokay,

    // tang nano 20k SDRAM
    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,   // chip select
    output wire        O_sdram_cas_n,  // columns addrefoc select
    output wire        O_sdram_ras_n,  // row address select
    output wire        O_sdram_wen_n,  // write enable
    inout  wire [31:0] IO_sdram_dq,    // 32 bit bidirectional data bus
    output wire [10:0] O_sdram_addr,   // 11 bit multiplexed address bus
    output wire [ 1:0] O_sdram_ba,     // two banks
    output wire [ 3:0] O_sdram_dqm,    // 32/4

    input  wire        w_rxd,
    output wire        w_txd,
    output wire [ 5:0] w_led,
    input  wire        w_btnl,
    input  wire        w_btnr,
    // when sdcard_pwr_n = 0, SDcard power on
    output wire        sdcard_pwr_n,
    // signals connect to SD controller
    output wire        m_psel,
    output wire        m_penable,
    output wire        m_pwrite,
    output wire [15:0] m_paddr,
    output wire [31:0] m_pwdata,
    input  wire [31:0] m_prdata,
    input  wire        m_pready,
    input  wire        m_pslverr,
    input  wire        m_sdsbusy,
    input  wire [31:0] m_sdspi_status,
    // display
    output wire        MAX7219_CLK,
    output wire        MAX7219_DATA,
    output wire        MAX7219_LOAD
);

    // This should be localparam but ISIM won't allow the $clog2 call for localparams
    // because of "reasons"
    parameter W_SRAM_ADDR = $clog2(DEPTH);  // 21 for tang nano
    localparam W_BYTES = W_DATA / 8;  // 4 bytes per word
    parameter W_BYTEADDR = $clog2(W_BYTES);  // 2


    // ----------------------------------------------------------------------------
    // AHBL state machine and buffering

    assign ahbls_hexokay = 1;

    // Need to buffer at least a write address,
    // and potentially the data too:
    reg [W_SRAM_ADDR-1:0] r_addr_saved;
    reg [W_DATA-1:0] r_wdata_saved;
    reg [W_BYTES-1:0] r_wmask_saved;
    reg r_wbuf_vld;
    reg r_read_delay_state;

    // Decode AHBL controls
    wire ahb_read_aphase = ahbls_htrans[1] && ahbls_hready && !ahbls_hwrite;
    wire ahb_write_aphase = ahbls_htrans[1] && ahbls_hready && ahbls_hwrite;

    // If we have a write buffer, we can hold onto buffered data during an
    // immediately following sequence of reads, and retire the buffer at a later
    // time. Otherwise, we must always retire the write immediately (directly from
    // the hwdata bus).
    wire write_retire = |r_wmask_saved && !(ahb_read_aphase && HAS_WRITE_BUFFER);
    wire wdata_capture = HAS_WRITE_BUFFER && !r_wbuf_vld && |r_wmask_saved && ahb_read_aphase;
    wire read_collision = !HAS_WRITE_BUFFER && write_retire && ahb_read_aphase; // = 0 when HAS_WRITE_BUFFER

    wire [W_SRAM_ADDR-1:0] haddr_row = ahbls_haddr[W_BYTEADDR+:W_SRAM_ADDR];
    wire [W_BYTES-1:0] wmask_noshift = ~({W_BYTES{1'b1}} << (1 << ahbls_hsize));
    wire [W_BYTES-1:0] wmask = wmask_noshift << ahbls_haddr[W_BYTEADDR-1:0];

    assign w_init_done = 1;

    // AHBL state machine (mainly controlling write buffer)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_wmask_saved <= {W_BYTES{1'b0}};
            r_addr_saved <= {W_SRAM_ADDR{1'b0}};
            r_wdata_saved <= {W_DATA{1'b0}};
            r_wbuf_vld <= 1'b0;
            r_read_delay_state <= 1'b0;
        end else begin
            if (ahb_write_aphase) begin
                r_wmask_saved <= wmask;
                r_addr_saved  <= haddr_row;
            end else if (write_retire) begin
                r_wmask_saved <= {W_BYTES{1'b0}};
            end
            if (read_collision) begin  // = 0 when HAS_WRITE_BUFFER
                r_addr_saved <= haddr_row;
            end
            if (wdata_capture) begin : capture
                integer i;
                r_wbuf_vld <= 1'b1;
                for (i = 0; i < W_BYTES; i = i + 1)
                if (r_wmask_saved[i]) r_wdata_saved[i*8+:8] <= ahbls_hwdata[i*8+:8];
            end else if (write_retire) begin
                r_wbuf_vld <= 1'b0;
            end
            r_read_delay_state <= read_collision;  // = 0 when HAS_WRITE_BUFFER
            if (r_read_delay_state) begin
                $display("sram sync r_read_delay_state");
                $finish;
            end
            if (read_collision && HAS_WRITE_BUFFER) begin
                $display("HAS_WRITE_BUFFER and read collision");
                $finish;
            end
            if (!ahbls_hready_resp) begin
                $display("HAS_WRITE_BUFFER and !ahbls_hready_resp");
                $finish;
            end

        end
        if (ahbls_htrans == 2'b01 || ahbls_htrans == 2'b11) begin
            $display("ahbls_htrans=%x not supported", ahbls_htrans);
            $finish;
        end
`ifdef laur0
        if (ahbls_haddr[1:0]) begin
            $display("ahbls_haddr=%x ", ahbls_haddr);
            $finish;
        end
`endif
    end

    // ----------------------------------------------------------------------------
    // SRAM and SRAM controls

    wire [W_BYTES-1:0] sram_wen = write_retire ? r_wmask_saved : {W_BYTES{1'b0}};
    // Note that following a read collision, the read address is supplied during the AHBL data phase
    wire [W_SRAM_ADDR-1:0] sram_addr = write_retire || r_read_delay_state/*0*/ ? r_addr_saved : haddr_row;
    wire [W_DATA-1:0] sram_wdata = r_wbuf_vld ? r_wdata_saved : ahbls_hwdata;
    wire [W_DATA-1:0] sram_rdata;

    sram_sync #(
        .WIDTH(W_DATA),
        .DEPTH(DEPTH),
        .BYTE_ENABLE(1),
        .PRELOAD_FILE(PRELOAD_FILE)
    ) sram (
        .clk  (clk),
        .d_pc (d_pc),
        .wen  (sram_wen),
        .ren  (ahb_read_aphase),
        .addr (sram_addr),
        .wdata(sram_wdata),
        .rdata(sram_rdata)
    );

    // ----------------------------------------------------------------------------
    // AHBL hookup


    assign ahbls_hresp = 1'b0;
    assign ahbls_hready_resp = !r_read_delay_state;  // = 1 when has write buffer

    // Merge buffered write data into AHBL read bus (note that r_addr_saved is the
    // address of a previous write, which will eventually be used to retire that
    // write, potentially during the write's corresponding AHBL data phase; and
    // r_haddr_dphase is the *current* ahbl data phase, which may be that of a read
    // which is preventing a previous write from retiring.)

    reg [W_SRAM_ADDR-1:0] r_haddr_dphase;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) r_haddr_dphase <= {W_SRAM_ADDR{1'b0}};
        else if (ahbls_hready) r_haddr_dphase <= haddr_row;

    wire addr_match = HAS_WRITE_BUFFER && r_haddr_dphase == r_addr_saved;
    genvar b;
    generate
        for (b = 0; b < W_BYTES; b = b + 1) begin : write_merge
            assign ahbls_hrdata[b * 8 +: 8] = addr_match && r_wbuf_vld && r_wmask_saved[b] ?
		r_wdata_saved[b * 8 +: 8] : sram_rdata[b * 8 +: 8];
        end
    endgenerate


endmodule
