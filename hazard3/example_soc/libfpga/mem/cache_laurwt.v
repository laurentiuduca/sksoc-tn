/* Modified by Laurentiu-Cristian Duca, 2024-12
 * spdx license identifier: Apache 2.0
 * write through cache
 * pipelined with arm ahb amba bus version 5
 * uses bram template
 */
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

    output reg  [6:0] state,
    output wire       c_oe,

    input wire [31:0] d_pc,

    output wire w_init_done,

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

    /***** store output data to registers in posedge clock cycle *****/
    //reg   [1:0] state = 0;

    // DRAM
    wire w_dram_busy;
    reg [31:0] r_dram_addr, r_dram_idata;
    wire [31:0] w_dram_odata;
    reg  [ 3:0] r_dram_mask;

    // Cache
    reg         c_clr;
    reg         c_we;
    wire [31:0] c_addr = (state <= 1) ? i_addr : r_dram_addr;
    reg  [31:0] c_idata;
    wire [31:0] c_odata;

    integer j = 0, k = 0;

    reg r_dram_le, r_dram_wr;

    assign o_busy = (state != 1 && state != 0) || (state == 1 && !c_oe) || !w_init_done;
    assign o_data = (state == 1 && c_oe) ? c_odata : w_dram_odata;

    wire sdram_fail;
    wire w_late_refresh;
    wire [7:0] w_mem_state;
    wire calib_done;

`ifdef SIM_MODE
    integer f;
    reg opened = 0, closed = 0;
    reg [31:0] timecnt = 0;
    always @(posedge clk) begin
        if (!opened) begin
            opened = 1;
            f = $fopen("cr", "w");
            if (f == 0) begin
                $display("ERROR: cr not opened");
                $finish;
            end
        end
        timecnt <= timecnt + 1;
        if (timecnt > 50000000) begin
            closed <= 1;
            $fclose(f);
            //$finish();     
        end
    end
`endif

    task check_new_req;
        if (w_init_done)
            if (i_rd_en) begin
                state <= 1;
                r_dram_addr <= i_addr;
                r_dram_mask <= i_mask;
            end else if (i_wr_en) begin
                state <= 10;
                c_clr <= 1;
                // write to ram only
                // will write to cache at next read on the same address
                r_dram_wr <= 1;
                r_dram_mask <= i_mask;
                r_dram_addr <= i_addr;
                r_dram_idata <= i_data;
            end else state <= 0;
    endtask

    always @(posedge clk or negedge rst_x) begin
        if (!rst_x) begin
            state <= 0;
            c_we <= 0;
            c_idata <= 0;
            r_dram_addr <= 0;
            r_dram_le <= 0;
            r_dram_wr <= 0;
            r_dram_idata <= 0;
            r_dram_mask <= 0;
        end else if (state == 0) begin
            check_new_req;
        end else if (state == 1) begin
            if (c_oe) begin
`ifdef SIM_MODE
                $fwrite(f, "mem read addr %8x data %8x\n", r_dram_addr, c_odata);
`endif
                check_new_req;
            end else begin
                // read from ram, then write to cache
                r_dram_le <= 1;
                state <= 2;
            end
        end else if (state == 2) begin
            if (w_dram_busy) begin
                state <= 3;
                r_dram_le <= 0;
            end
        end else if (state == 3) begin
            if (!w_dram_busy) begin
                c_we <= 1;
                c_idata <= w_dram_odata;
                state <= 4;
            end
        end else if (state == 4) begin
            c_we  <= 0;
            state <= 0;
`ifdef SIM_MODE
            $fwrite(f, "mem read addr %8x data %8x\n", r_dram_addr, w_dram_odata);
`endif
        end else if (state == 10) begin
            c_clr <= 0;
            if (w_dram_busy) begin
                state <= 11;
                r_dram_wr <= 0;
                //c_clr <= 0;
            end
        end else if (state == 11) begin
            if (!w_dram_busy) begin
`ifdef SIM_MODE
                $fwrite(f, "mem write addr %8x data %8x mask %1x\n", r_dram_addr, r_dram_idata,
                        r_dram_mask);
`endif
                state <= 0;
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

    m_maintn #(
        .PRELOAD_FILE(PRELOAD_FILE)
    ) boot (
        // user interface ports
        .i_rd_en(r_dram_le),
        .i_wr_en(r_dram_wr),
        .i_addr(r_dram_addr),
        .i_data(r_dram_idata),
        .o_data(w_dram_odata),
        .o_busy(w_dram_busy),
        .i_ctrl(r_dram_mask),
        .sys_state(state),  // not used
        .w_bus_cpustate(4'h0),  // not used
        .w_mem_state(w_mem_state),  // not used

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
        // signals connect to SD controller
        .m_psel(m_psel),
        .m_penable(m_penable),
        .m_pwrite(m_pwrite),
        .m_paddr(m_paddr),
        .m_pwdata(m_pwdata),
        .m_prdata(m_prdata),
        .m_pready(m_pready),
        .m_pslverr(m_pslverr),
        .m_sdsbusy(m_sdsbusy),
        .m_sdspi_status(m_sdspi_status),
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
    output reg [WIDTH-1:0] r_odata;

    reg     [WIDTH-1:0] mem[0:ENTRY-1];

    integer             i;
    initial for (i = 0; i < ENTRY; i = i + 1) mem[i] = 0;

    always @(posedge CLK) begin
        if (w_we) begin
            mem[w_addr] <= w_idata;
            r_odata <= w_idata;
        end else r_odata <= mem[w_addr];
    end

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
    reg [               $clog2(ENTRY)-1:0] r_idx = 0;
    reg [(ADDR_WIDTH - $clog2(ENTRY))-1:0] r_tag = 0;

    // index and tag
    wire [$clog2(ENTRY)-1:0] w_idx, wlidx;
    wire [(ADDR_WIDTH - $clog2(ENTRY))-1:0] w_tag, wltag;
    assign {w_tag, w_idx} = w_addr;
    assign {wltag, wlidx} = 32'h119f0;

    wire w_mwe = w_clr | w_we | !RST_X | w_flush;
    wire [$clog2(ENTRY)-1:0] w_maddr = w_idx;
    wire [ADDR_WIDTH - $clog2(
ENTRY
) + D_WIDTH:0] w_mwdata = w_we ? {1'b1, w_tag, w_idata} : {1'b0, {(ADDR_WIDTH - $clog2(
        ENTRY
    )) {1'b0}}, {D_WIDTH{1'b0}}};
    wire [ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH:0] w_modata;

    wire w_mvalid;
    wire [$clog2(ENTRY)-1:0] w_midx;
    wire [(ADDR_WIDTH - $clog2(ENTRY))-1:0] w_mtag;
    wire [D_WIDTH-1:0] w_mdata;
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
    assign w_oe    = (w_mvalid && w_mtag == r_tag);

    integer l = 0;
    always @(posedge CLK) begin
        r_tag <= w_tag;
        r_idx <= w_idx;
    end
endmodule
/**************************************************************************************************/

