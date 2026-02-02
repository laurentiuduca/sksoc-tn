// Modified by Laurentiu Cristian Duca, 2025/08
// spdx license identifier - apache 2

`include "define.vh"

module m_topsim (
`ifndef ICARUS
    input  wire        clk,
`endif
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

    input  wire       i_rx,
    output wire       o_tx,
    output wire [5:0] w_led,
    input  wire       w_btnl,
    input  wire       w_btnr,
    // when sdcard_pwr_n = 0, SDcard power on
    output wire       sdcard_pwr_n,
    // signals connect to SD bus
    output wire       sdclk,
    inout  wire       sdcmd,
    inout  wire       sddat0,
    inout  wire       sddat1,
    sddat2,
    sddat3,
    // display
    output wire       MAX7219_CLK,
    output wire       MAX7219_DATA,
    output wire       MAX7219_LOAD
);

`ifdef ICARUS
    reg clk = 0;
    always begin
        clk = 0;
        #5;
        clk = 1;
        #5;
    end
`endif

    wire pll_clk, clk_sdram;
`ifdef SIM_MODE
    assign pll_clk   = clk;
    assign clk_sdram = clk;
`else
    Gowin_rPLL_nes pll_nes (
        .clkin  (clk),
        .clkout (pll_clk),   // FREQ main clock
        .clkoutp(clk_sdram)  // FREQ main clock phase shifted
    );
`endif

    wire w_rxd = 1;
    wire w_txd, uart_tx;
    assign o_tx = w_init_done ? uart_tx : w_txd;
    wire w_init_done;

    reg  RST_X = 0;
    example_soc #(
        .SRAM_DEPTH(1 << 21),  // 2 Mwords x 4 -> 8MB
        .CLK_MHZ   (27)        // For timer timebase
    ) es (
        // System clock + reset
        .clk(pll_clk),
        .rst_n(RST_X),
        .clk_sdram(clk_sdram),

        // JTAG port to RISC-V JTAG-DTM
        .tck(1'b0),
        .trst_n(1'b0),
        .tms(1'b0),
        .tdi(1'b1),
        .tdo(),

        // IO
        .uart_tx(uart_tx),
        .uart_rx(1'b1),

        // tang nano 20k SDRAM
        .O_sdram_clk  (O_sdram_clk),
        .O_sdram_cke  (O_sdram_cke),
        .O_sdram_cs_n (O_sdram_cs_n),   // chip select
        .O_sdram_cas_n(O_sdram_cas_n),  // columns addrefoc select
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
        .w_init_done(w_init_done),
        // display
        .MAX7219_CLK(MAX7219_CLK),
        .MAX7219_DATA(MAX7219_DATA),
        .MAX7219_LOAD(MAX7219_LOAD)
    );

    // reset
    reg [31:0] cnt = 0;
    always @(posedge clk) begin
        if (cnt > 20) RST_X <= 1;
        if (cnt >= 32'h2220) begin
`ifdef DUMP_VCD
            $display("time to finish %d", $time);
            $finish;
`else
            ;
`endif
        end else cnt <= cnt + 1;
    end

`ifdef DUMP_VCD
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
    end
`endif

endmodule
