/* Modified by Laurentiu-Cristian Duca, 2024-12
 * spdx license identifier: Apache 2.0
 * write through cache
 * read in the same period when hit
 *
 */
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** Memory Module v0.02                                                                      ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/

/**** Memory Controller with Cache                                                             ****/

/**************************************************************************************************/

module cache_ctrl #(
    parameter PRELOAD_FILE = "",
    parameter ADDR_WIDTH   = 23
) (
    input  wire        clk,
    input  wire        rst_x,
    input  wire        clk_sdram,
    // user interface ports
    input  wire        i_rd_en,
    input  wire        i_wr_en,
    input  wire [31:0] i_addr,
    input  wire [31:0] i_data,
    output wire [31:0] o_data,
    output wire        o_busy,
    input  wire [ 3:0] i_mask,

    output wire [6:0] state,
    output wire       c_oe,

    input wire [31:0] d_pc,

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

    reg [1:0] r_cache_state;
    assign state = {4'h0, r_cache_state};
    reg         r_wait = 0;

    /***** store output data to registers in posedge clock cycle *****/
    //reg   [1:0] r_cache_state = 0;

    reg  [31:0] r_addr = 0;
    reg  [ 2:0] r_ctrl = 0;
    reg  [31:0] r_o_data = 0;

    // DRAM
    wire        w_dram_stall;
    wire        w_dram_le;
    wire [31:0] w_dram_addr = i_addr;  //(i_wr_en) ? i_addr : r_addr;
    wire [31:0] w_dram_odata;

    // Cache
    //wire        c_oe;
    wire        c_clr = (r_cache_state == 2'b11 && c_oe);
    wire        c_we = (r_cache_state == 2'b10 && !w_dram_stall);
    wire [31:0] c_addr = i_addr;  //(r_cache_state == 2'b00) ? i_addr : r_addr;
    wire [31:0] c_idata = w_dram_odata;
    wire [31:0] c_odata;
    /*
    cache states:
        2'b00=idle,
        (2'b01=read && c_oe)=read made in c_odata,
        2'b10=cache read miss;
        2'b11=write

    */
    always @(posedge clk or negedge rst_x) begin
        if (!rst_x) begin
            r_cache_state <= 0;
            r_wait <= 0;
        end else begin

            if (r_cache_state == 2'b01 && !c_oe) begin
                r_cache_state <= 2'b10;
            end
        else if(r_cache_state == 2'b11 || (r_cache_state == 2'b01 && c_oe)
                || (r_cache_state == 2'b10 && !w_dram_stall)) begin
                r_cache_state <= 2'b00;
                r_o_data <= (r_cache_state == 2'b01) ? c_odata : w_dram_odata;
            end else if (i_wr_en) begin
                r_cache_state <= 2'b11;
                r_addr <= i_addr;
            end else if ((i_rd_en && !c_oe) || r_wait) begin
                if (w_init_done) begin
                    r_cache_state <= 2'b01;
                    r_addr <= i_addr;
                    r_wait <= 0;
                end else r_wait <= 1;
            end
        end
    end

    m_dram_cache #(ADDR_WIDTH, 32, `CACHE_SIZE / 4) cache (
        clk,
        1'b1,
        1'b0,
        c_clr,
        c_we,
        c_addr[31:0],
        c_idata,
        c_odata,
        c_oe
    );

    assign w_dram_le = (r_cache_state == 2'b01 && !c_oe);

    assign o_busy = w_dram_stall || (r_cache_state != 0 && !(r_cache_state == 2'b00 && c_oe));
    assign o_data = (r_cache_state == 2'b00 && c_oe) ? c_odata : r_o_data;

    wire sdram_fail;
    wire w_late_refresh;
    wire [7:0] w_mem_state;
    wire calib_done;
    wire w_init_done;


    m_maintn #(
        .PRELOAD_FILE(PRELOAD_FILE)
    ) boot (
        // user interface ports
        .i_rd_en(w_dram_le),
        .i_wr_en(i_wr_en),
        .i_addr(w_dram_addr),
        .i_data(i_data),
        .o_data(w_dram_odata),
        .o_busy(w_dram_stall),
        .i_ctrl(i_mask),
        .sys_state(r_cache_state),  // not used
        .w_bus_cpustate(0),  // not used
        .mem_state(w_mem_state),  // not used

        .w_init_done(w_init_done),
        .d_pc(d_pc),

        .clk(clk),
        .rst_x(rst_x),
        .clk_sdram(clk_sdram),
        .o_init_calib_complete(calib_done),
        .sdram_fail(sdram_fail),

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

/**************************************************************************************************/

/*** Single-port RAM with synchronous read                                                      ***/
module m_bram #(
    parameter WIDTH = 32,
    ENTRY = 256
) (
    CLK,
    w_we,
    w_addr,
    w_idata,
    r_odata
);
    input wire CLK, w_we;
    input wire [$clog2(ENTRY)-1:0] w_addr;
    input wire [WIDTH-1:0] w_idata;
    output wire [WIDTH-1:0] r_odata;

    reg     [WIDTH-1:0] mem[0:ENTRY-1];

    integer             i;
    initial for (i = 0; i < ENTRY; i = i + 1) mem[i] = 0;

    always @(posedge CLK) begin
        if (w_we) mem[w_addr] <= w_idata;
        //r_odata <= mem[w_addr];
    end
    assign r_odata = mem[w_addr];
endmodule

/**************************************************************************************************/
/*** Simple Direct Mapped Cache Sync CLK for DRAM                                               ***/
/**************************************************************************************************/
module m_dram_cache #(
    parameter ADDR_WIDTH = 30,
    D_WIDTH = 32,
    ENTRY = 1024
) (
    CLK,
    RST_X,
    w_flush,
    w_clr,
    w_we,
    w_addr,
    w_idata,
    w_odata,
    w_oe
);
    input wire CLK, RST_X;
    input wire w_flush, w_we, w_clr;
    input wire [ADDR_WIDTH-1:0] w_addr;
    input wire [D_WIDTH-1:0] w_idata;
    output wire [D_WIDTH-1:0] w_odata;
    output wire w_oe;  //output enable

    // index and tag
    reg  [               $clog2(ENTRY)-1:0] r_idx = 0;
    reg  [(ADDR_WIDTH - $clog2(ENTRY))-1:0] r_tag = 0;

    // index and tag
    wire [               $clog2(ENTRY)-1:0] w_idx;
    wire [(ADDR_WIDTH - $clog2(ENTRY))-1:0] w_tag;
    assign {w_tag, w_idx} = w_addr;

    wire                                          w_mwe = w_clr | w_we | !RST_X | w_flush;
    wire [                     $clog2(ENTRY)-1:0] w_maddr = w_idx;
    wire [ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH:0] w_mwdata = w_we ? {1'b1, w_tag, w_idata} : 0;
    wire [ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH:0] w_modata;

    wire                                          w_mvalid;
    wire [                     $clog2(ENTRY)-1:0] w_midx;
    wire [      (ADDR_WIDTH - $clog2(ENTRY))-1:0] w_mtag;
    wire [                           D_WIDTH-1:0] w_mdata;
    assign {w_mvalid, w_mtag, w_mdata} = w_modata;


    m_bram #((ADDR_WIDTH - $clog2(
        ENTRY
    ) + D_WIDTH) + 1, ENTRY) mem (
        CLK,
        w_mwe,
        w_maddr,
        w_mwdata,
        w_modata
    );

    assign w_odata = w_mdata;
    assign w_oe    = (w_mvalid && w_mtag == w_tag);

    always @(posedge CLK) begin
        r_tag <= w_tag;
        r_idx <= w_idx;
    end
endmodule
/**************************************************************************************************/

