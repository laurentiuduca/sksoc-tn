// Modified by Laurentiu Cristian Duca, 2025/08
// spdx license identifier - apache 2


module ahb_async_sram #(
    parameter W_DATA = 32,
    parameter W_ADDR = 32,
    parameter DEPTH = 1 << 11,
    parameter W_SRAM_ADDR = $clog2(DEPTH)  // Let this default
) (
    // Globals
    input wire clk,
    input wire rst_n,

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

    output reg  [W_SRAM_ADDR-1:0] sram_addr,
    inout  wire [     W_DATA-1:0] sram_dq,
    output reg                    sram_ce_n,
    output wire                   sram_we_n,   // DDR output
    output reg                    sram_oe_n,
    output reg  [   W_DATA/8-1:0] sram_byte_n,

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

    parameter W_BYTEADDR = $clog2(W_DATA / 8);

    // Tie off unused AHBL signals

    assign ahbls_hready_resp = 1'b1;
    assign ahbls_hresp = 1'b0;

    // Combinatorially generate the byte strobes from address + size buses

    wire [W_DATA/8-1:0] bytemask_noshift = ~({W_DATA / 8{1'b1}} << (8'h1 << ahbls_hsize));
    wire [W_DATA/8-1:0] bytemask = bytemask_noshift << ahbls_haddr[W_BYTEADDR-1:0];

    // AHBL request marshalling/translation

    wire we_next = ahbls_htrans[1] && ahbls_hwrite && ahbls_hready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_addr   <= {W_SRAM_ADDR{1'b0}};
            sram_ce_n   <= 1'b1;
            sram_oe_n   <= 1'b1;
            sram_byte_n <= {W_DATA / 8{1'b1}};
        end else if (ahbls_hready) begin
            if (ahbls_htrans[1]) begin
                sram_addr   <= ahbls_haddr[W_BYTEADDR+:W_SRAM_ADDR];
                sram_ce_n   <= 1'b0;
                sram_oe_n   <= ahbls_hwrite;
                sram_byte_n <= ~bytemask;
            end else begin
                sram_ce_n   <= 1'b1;
                sram_oe_n   <= 1'b1;
                sram_byte_n <= {W_DATA / 8{1'b1}};
            end
        end
    end

    ddr_out we_ddr (
        .clk   (clk),
        .rst_n (rst_n),
        .d_rise(1'b1),
        .d_fall(!we_next),
        .q     (sram_we_n)
    );

    // SRAM tristating

    wire [W_DATA-1:0] sram_q;
    assign ahbls_hrdata = sram_q & {W_DATA{!sram_oe_n}};

    tristate_io iobuf[W_DATA-1:0] (
        .out(ahbls_hwdata),
        .oe (sram_oe_n),
        .in (sram_q),
        .pad(sram_dq)
    );

endmodule
