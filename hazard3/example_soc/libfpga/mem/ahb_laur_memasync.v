// wrote by laurentiu cristian duca
// spdx license identifier: Apache 2.0


`include "define.vh"

module ahb_sync_sram #(
    //parameter W_DATA = 32,
    //parameter W_ADDR = 32,
    parameter DEPTH = 1 << 21,  // tang nano
    parameter HAS_WRITE_BUFFER = 1,  // not used
    parameter PRELOAD_FILE = "",
    parameter W_MEMOP = 5,
    `include "hazard3_config.vh"
) (
    // Globals
    input wire clk,
    input wire rst_n,
    input wire clk_sdram,

    input wire [ W_ADDR-1:0] d_pc,
    input wire [W_MEMOP-1:0] xm_memop,

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

    input  wire       w_rxd,
    output wire       w_txd,
    output wire [5:0] w_led,
    input  wire       w_btnl,
    input  wire       w_btnr,
    // when sdcard_pwr_n = 0, SDcard power on
    output wire       sdcard_pwr_n,
    // signals connect to SD bus
    output wire       sdclk,
    inout  wire       sdcmd,
    input  wire       sddat0,
    output wire       sddat1,
    sddat2,
    sddat3,
    // display
    output wire       MAX7219_CLK,
    output wire       MAX7219_DATA,
    output wire       MAX7219_LOAD
);

    // ----------------------------------------------------------------------------
    // AHBL state machine 

    wire [3:0] wmask_noshift = ~({4{1'b1}} << (1 << ahbls_hsize));
    wire [3:0] wmask = wmask_noshift << ahbls_haddr[1:0];

    task check_new_req;
        if (ahb_read_aphase) begin
            r_ahbls_haddr <= ahbls_haddr;
            if (state == 11 || state == 10) begin
                r_dram_le <= 1;
                state <= 10;
            end else begin
                r_dram_le <= 0;
                state <= 12;
            end
            r_mask <= wmask;
        end else if (ahb_write_aphase) begin
            r_ahbls_haddr <= ahbls_haddr;
            state <= 22;
            r_mask <= wmask;
            r_ahbls_hwdata <= ahbls_hwdata;  // this must also be in state 22
            r_dram_le <= 0;
        end else begin
            r_dram_le <= 0;
            state <= 0;
        end
    endtask

    // Decode AHBL controls
    wire ahb_read_aphase = ahbls_htrans[1] && ahbls_hready && !ahbls_hwrite;
    wire ahb_write_aphase = ahbls_htrans[1] && ahbls_hready && ahbls_hwrite;

    reg [5:0] state, ostate;
    reg [W_ADDR-1:0] r_ahbls_haddr;
    reg [       3:0] r_mask;
    reg [W_DATA-1:0] r_ahbls_hrdata, r_ahbls_hwdata;
    integer i = 0, j = 0, k = 0, l = 0, m = 0, lj = 0;
    // AHBL state machine (mainly controlling write buffer)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            ostate <= 0;
            r_mask <= 0;
            r_dram_le <= 0;
            r_dram_wr <= 0;
            r_ahbls_hrdata <= 0;
            r_ahbls_hwdata <= 0;
            //if(state == 0)
            //	check_new_req;
        end else begin
            if (state == 0) begin
                if (ahb_read_aphase) begin
                    r_dram_le <= 1;
                    r_ahbls_haddr <= ahbls_haddr;
                    state <= 10;
                    r_mask <= wmask;
                end else if (ahb_write_aphase) begin
                    r_ahbls_haddr <= ahbls_haddr;
                    state <= 22;
                    r_mask <= wmask;
                    r_ahbls_hwdata <= ahbls_hwdata;  // this must also be in state 22
                end
            end else if (state == 10) begin
                // read
                if (w_dram_busy) begin
                    state <= 11;
                    r_dram_le <= 0;
                end else if (w_cache_state == 0 && w_c_oe) begin
                    // we have data
                    //r_dram_le <= 0;
                    r_ahbls_hrdata <= w_dram_odata;
                    //state <= 0;
                    // do we have new address phase on this data phase?
                    check_new_req;
                end
            end else if (state == 11) begin
                if (!w_dram_busy) begin
                    // done
                    r_ahbls_hrdata <= w_dram_odata;
                    //state <= 0;
                    check_new_req;
                end
            end else if (state == 12) begin
                r_dram_le <= 1;
                state <= 10;
            end else if (state == 20) begin
                if (w_dram_busy) begin
                    state <= 21;
                    r_dram_wr <= 0;
                end
            end else if (state == 21) begin
                if (!w_dram_busy) begin
                    check_new_req;
                    //state <= 0;
                end
            end else if (state == 22) begin
                r_ahbls_hwdata <= ahbls_hwdata;
                r_dram_wr <= 1;
                state <= 20;
                if (ahb_read_aphase || ahb_write_aphase) begin
                    $display("ahb_read_aphase or write aphase in write dphase");
                    $finish;
                end
            end


            if (ahbls_htrans == 2'b01 || ahbls_htrans == 2'b11) begin
                $display("ahbls_htrans=%x not supported", ahbls_htrans);
                $finish;
            end

        end

    end
    // ----------------------------------------------------------------------------
    // AHBL hookup


    assign ahbls_hresp = 1'b0;
    assign ahbls_hready_resp = (state == 0) ? 0 :
			   (state == 10) ? ((w_cache_state == 0 && w_c_oe) ? 1 : 0) :
			   (state == 11) ? (w_dram_busy ? 0 : 1) :
			   (state == 12) ? 0 :
			   (state == 22 || state == 20) ? 0 :
			   (state == 21) ? (w_dram_busy ? 0 : 1) : 0;
    assign ahbls_hrdata = w_dram_odata;
    //r_ahbls_hrdata;

    // ----------------------------------------------------------------------------
    // RAM 
    reg r_dram_le, r_dram_wr;
    wire sdram_fail;
    wire w_late_refresh;
    wire [7:0] w_mem_state;
    wire w_dram_busy;
    wire calib_done;
    wire [31:0] w_dram_odata;
    wire w_wr_en = r_dram_wr;
    wire w_dram_le = r_dram_le;

    wire [6:0] w_cache_state;
    wire w_c_oe;

    cache_ctrl #(
        .PRELOAD_FILE(PRELOAD_FILE),
        .ADDR_WIDTH  (32)
    ) cache_ctrl (
        // output clk, rst (active-low)
        .clk(clk),
        .rst_x(rst_n),
        .clk_sdram(clk_sdram),
        .d_pc(d_pc),
        // user interface ports
        .i_rd_en(w_dram_le),
        .i_wr_en(w_wr_en),
        .i_addr({r_ahbls_haddr[W_DATA-1:2], 2'b00}),
        .i_data(r_ahbls_hwdata),
        .o_data(w_dram_odata),
        .o_busy(w_dram_busy),
        .i_mask(r_mask),

        .state(w_cache_state),
        .c_oe (w_c_oe),

        .O_sdram_clk  (O_sdram_clk),
        .O_sdram_cke  (O_sdram_cke),
        .O_sdram_cs_n (O_sdram_cs_n),   // chip select
        .O_sdram_cas_n(O_sdram_cas_n),  // columns address select
        .O_sdram_ras_n(O_sdram_ras_n),  // row address select
        .O_sdram_wen_n(O_sdram_wen_n),  // write enable
        .IO_sdram_dq  (IO_sdram_dq),    // 32 bit bidirectional data bus
        .O_sdram_addr (O_sdram_addr),   // 11 bit multiplexed address bus
        .O_sdram_ba   (O_sdram_ba),     // two banks
        .O_sdram_dqm  (O_sdram_dqm),    // 32/4

        .w_rxd(w_rxd),
        .w_txd(w_txd),
        .w_led(w_led),
        .w_btnl(w_btnl),
        .w_btnr(w_btnr),
        // when sdcard_pwr_n = 0, SDcard power on
        .sdcard_pwr_n(sdcard_pwr_n),
        // signals connect to SD bus
        .sdclk(sdclk),
        .sdcmd(sdcmd),
        .sddat0(sddat0),
        .sddat1(sddat1),
        .sddat2(sddat2),
        .sddat3(sddat3),
        // display
        .MAX7219_CLK(MAX7219_CLK),
        .MAX7219_DATA(MAX7219_DATA),
        .MAX7219_LOAD(MAX7219_LOAD)
    );
endmodule
