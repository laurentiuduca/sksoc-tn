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

    // ----------------------------------------------------------------------------
    // AHBL state machine 

    wire [3:0] wmask_noshift = ~({4{1'b1}} << (1 << ahbls_hsize));
    wire [3:0] wmask = wmask_noshift << ahbls_haddr[1:0];

    // Decode AHBL controls
    wire ahb_read_aphase = ahbls_htrans[1] && ahbls_hready && !ahbls_hwrite;
    wire ahb_write_aphase = ahbls_htrans[1] && ahbls_hready && ahbls_hwrite;

    reg [5:0] state, ostate;
    reg [W_ADDR-1:0] r_ahbls_haddr;
    reg [       3:0] r_mask;
    reg [W_DATA-1:0] r_ahbls_hrdata, r_ahbls_hwdata;
    reg r_ahbls_hexokay;
    integer i = 0, j = 0, k = 0, l = 0, m = 0, lj = 0;


    // RAM 
    reg r_dram_le, r_dram_wr;
    wire sdram_fail;
    wire w_late_refresh;
    wire [7:0] w_mem_state;
    wire w_dram_busy;
    wire calib_done;
    wire [31:0] w_dram_odata;
    wire w_wr_en = r_dram_wr;
    wire w_dram_le = ahb_read_aphase;
    wire [31:0] w_addr = (state == 22 || state == 20) ? {r_ahbls_haddr[W_DATA-1:2], 2'b00} :
            {ahbls_haddr[W_DATA-1:2], 2'b00};

    wire [6:0] w_cache_state;
    wire w_c_oe;
    wire [3:0] w_cache_mask;
    assign w_cache_mask = (state == 0 || state == 22 && !w_dram_busy) ? wmask : r_mask;

    reg [W_ADDR-1:0] r_excl_addr[0:N_HARTS-1];
    reg r_excl_addr_valid[0:N_HARTS-1];
    reg exclwrdisplay;
    task check_new_req;
        if (ahb_read_aphase) begin
            state  <= 0;
            //r_ahbls_haddr <= ahbls_haddr;
            r_mask <= wmask;
            // exclusive transfers
            if (ahbls_hexcl) begin
                r_ahbls_hexokay <= 1;
                r_excl_addr[hartid] <= ahbls_haddr;
                r_excl_addr_valid[hartid] <= 1;
            end
        end else if (ahb_write_aphase) begin
            if (ahbls_hexcl) begin
                if (r_excl_addr[hartid] == ahbls_haddr && r_excl_addr_valid[hartid]) begin
                    r_ahbls_hexokay <= 1;
                    for (i = 0; i < N_HARTS; i = i + 1)
                    if (r_excl_addr[i] == ahbls_haddr) r_excl_addr_valid[i] <= 0;
                    r_ahbls_haddr <= ahbls_haddr;
                    state <= 22;
                    r_mask <= wmask;
                    r_ahbls_hwdata <= ahbls_hwdata;  // this must also be in state 22
                    exclwrdisplay <= 1;
                end else begin
`ifdef dbghexcl
                    $display("--exclusive write fail at addr %x h%1x pc=%x", ahbls_haddr, hartid,
                             d_pc);
`endif
                    state <= 30;
                    r_ahbls_hexokay <= 0;
                    //$finish;
                end
            end else begin
                r_ahbls_hexokay <= 0;
                r_ahbls_haddr <= ahbls_haddr;
                state <= 22;
                r_mask <= wmask;
                r_ahbls_hwdata <= ahbls_hwdata;  // this must also be in state 22
            end
        end else begin
            state <= 0;
        end
    endtask
    task check_debug;
`ifdef SIM_MODE
`ifdef dbgstart
        if ((ahb_read_aphase || ahb_write_aphase) && k < 10) begin
            $display(
                "d_pc=%x hartid=%1x ahb_read_aphase=%x || ahb_write_aphase=%x state=%d ahbls_haddr=%x time %8d",
                d_pc, hartid, ahb_read_aphase, ahb_write_aphase, state, ahbls_haddr, $time);
            k <= k + 1;
        end
`endif
`endif
    endtask

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
            r_ahbls_hexokay <= 1;
            //r_excl_addr_valid[0] <= 0;
            //r_excl_addr_valid[1] <= 0;
            for (i = 0; i < N_HARTS; i = i + 1) r_excl_addr_valid[i] <= 0;
            exclwrdisplay <= 0;
        end else begin
            r_ahbls_hexokay <= 1;
            if (state == 0) begin
                check_new_req;
                check_debug;
            end else if (state == 20) begin
                if (w_dram_busy) begin
                    state <= 21;
                    r_dram_wr <= 0;
                end
            end else if (state == 21) begin
                if (!w_dram_busy) begin
                    check_debug;
                    check_new_req;
                end
            end else if (state == 22) begin
                r_ahbls_hwdata <= ahbls_hwdata;
                r_dram_wr <= 1;
                state <= 20;
                if (ahb_read_aphase || ahb_write_aphase) begin
                    $display("ahb_read_aphase or write aphase in write dphase");
                    $finish;
                end
`ifdef dbghexcl
                if (exclwrdisplay) begin
                    exclwrdisplay <= 0;
                    $display("--exclusive write succ at addr %x h%1x pc=%x data=%x", ahbls_haddr,
                             hartid, d_pc, ahbls_hwdata);
                end
`endif
            end else if (state == 30) begin
                // excl write fail
                r_ahbls_hexokay <= 0;
                state <= 31;
            end else if (state == 31) begin
                // excl write fail
                check_new_req;
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
    assign ahbls_hready_resp = (state == 0) ? !w_dram_busy : 
			   (state == 21) ? !w_dram_busy : (state == 31);
    assign ahbls_hrdata = w_dram_odata;

    assign ahbls_hexokay = r_ahbls_hexokay;
    // ----------------------------------------------------------------------------

    cache_ctrl #(
        .PRELOAD_FILE(PRELOAD_FILE),
        .ADDR_WIDTH  (32)
    ) cache_ctrl (
        // output clk, rst (active-low)
        .clk(clk),
        .rst_x(rst_n),
        .clk_sdram(clk_sdram),
        .d_pc(d_pc),
        .w_init_done(w_init_done),

        // user interface ports
        .i_rd_en(w_dram_le),
        .i_wr_en(w_wr_en),
        .i_addr (w_addr),
        .i_data (r_ahbls_hwdata),
        .o_data (w_dram_odata),
        .o_busy (w_dram_busy),
        .i_mask (w_cache_mask),

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
