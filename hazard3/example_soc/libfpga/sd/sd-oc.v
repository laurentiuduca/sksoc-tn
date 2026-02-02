
`include "define.vh"
`include "sd_defines.h"

module hazard3_sd #(
    parameter DEVADDR = 16'h8000,
    parameter W_ADDR = 32,
    parameter W_DATA = 32,
    parameter ramdisk = "example_soc/libfpga/sd/ramdisk2.hex",
    parameter sd_model_log_file = {"sd_model.log"}
    //parameter wb_memory_file={`BIN_DIR, "/wb_memory.txt"})
) (
    input wire clk,
    input wire rst_n,

`ifdef laur0
    // AHB5 Master port
    output reg  [W_ADDR-1:0] haddr,
    output reg               hwrite,
    output reg  [       1:0] htrans,
    output reg  [       2:0] hsize,
    output wire [       2:0] hburst,
    output reg  [       3:0] hprot,
    output wire              hmastlock,
    //output reg  [7:0]         hmaster,
    output reg               hexcl,
    input  wire              hready,
    input  wire              hresp,
    //input  wire               hexokay,
    output reg  [W_DATA-1:0] hwdata,
    input  wire [W_DATA-1:0] hrdata,
`endif

    // APB Port
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [15:0] paddr,
    input wire [31:0] pwdata,
    output reg [31:0] prdata,
    output reg pready,
    output wire pslverr,

    // sd signals
    output wire sd_clk_pad_o,
    inout wire sd_cmd,
    input wire sd_cmd_i,
    output wire sd_cmd_oe,
    inout wire [3:0] sd_dat,
    output wire sd_dat_oe,
    input wire [3:0] sd_dat_i
);

    wire wb_clk = clk;
    wire wb_rst = !rst_n;
    reg [31:0] wbs_sds_dat_i;
    wire [31:0] wbs_sds_dat_o;
    reg [31:0] wbs_sds_adr_i;
    reg [3:0] wbs_sds_sel_i;
    reg wbs_sds_we_i;
    reg wbs_sds_cyc_i;
    reg wbs_sds_stb_i;
    wire wbs_sds_ack_o;
    wire [31:0] wbm_sdm_adr_o;
    wire [3:0] wbm_sdm_sel_o;
    wire wbm_sdm_we_o;
    reg [31:0] wbm_sdm_dat_i;
    wire [31:0] wbm_sdm_dat_o;
    wire wbm_sdm_cyc_o;
    wire wbm_sdm_stb_o;
    reg wbm_sdm_ack_i;
    wire [2:0] wbm_sdm_cti_o;
    wire [1:0] wbm_sdm_bte_o;

    //wire sd_cmd_oe;
    //wire sd_dat_oe;
    wire cmdIn;
    wire [3:0] datIn;
    //tri sd_cmd;
    //tri [3:0] sd_dat;

`ifdef SIM_MODE
    assign sd_cmd = sd_cmd_oe ? cmdIn : 1'bz;
    assign sd_dat = sd_dat_oe ? datIn : 4'bz;
`else
    assign sd_cmd = sd_cmd_oe ? cmdIn : sd_cmd_i;
    assign sd_dat = sd_dat_oe ? datIn : sd_dat_i;
`endif

    //wire sd_clk_pad_o;
    wire int_cmd, int_data;

    reg [7:0] state;
    reg [31:0] rwdata;

    wire bus_write = pwrite && psel && penable;
    wire bus_read = !pwrite && psel && penable;

    `define BLOCK_SIZE 16'h200
    `define BLOCK_ADDR (DEVADDR + `BLOCK_SIZE)
    `define ADDRUH 16'h4000

    // our block mem
    reg [31:0] bidata1, bidata2, baddr1, baddr2;
    wire [31:0] bodata1, bodata2;
    reg bwr1, bwr2;
    wire bwr = bwr1 | bwr2;
    wire [31:0] bidata = bwr2 ? bidata2 : bidata1;
    wire [31:0] baddr = bwr2 ? baddr2 : baddr1;
    reg [31:0] mem[0:`BLOCK_SIZE/4-1];
    initial for (integer i = 0; i < `BLOCK_SIZE / 4; i = i + 1) mem[i] = 0;
    always @(posedge clk) begin
        if (bwr) mem[baddr] <= bidata;
        //bodata1 <= mem[baddr1];
        //bodata2 <= mem[baddr2];
    end
    assign bodata1 = mem[baddr1];
    assign bodata2 = mem[baddr2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            pready <= 0;
            rwdata <= 0;
            bidata1 <= 0;
            baddr1 <= 0;
            bwr1 <= 0;
        end else if (state == 0) begin
            pready <= 0;
            if (bus_write) begin
                $display("bus w paddr_i=%x ack_o=%x pwdata=%x", paddr, wbs_sds_ack_o, pwdata);
                if (paddr == 16'h8100) begin
                    $display("finish");
                    $finish;
                end
                if (paddr < `BLOCK_ADDR) begin
                    // cmd
                    state <= 2;
                    pready <= 0;
                    wbs_sds_dat_i <= pwdata;
                    wbs_sds_adr_i <= {`ADDRUH, paddr};
                    wbs_sds_sel_i <= 4'hf;
                    wbs_sds_we_i <= 1;
                    wbs_sds_cyc_i <= 1;
                    wbs_sds_stb_i <= 1;
                end else begin
                    // write to our block mem
                    pready <= 0;
                    state <= 5;
                    bidata1 <= pwdata;
                    baddr1 <= paddr - DEVADDR;
                    bwr1 <= 1;
                end
            end else if (bus_read) begin
                $display("bus r paddr=%x ack_o=%x", paddr, wbs_sds_ack_o);
                if (paddr < `BLOCK_ADDR) begin
                    // cmd
                    state <= 12;
                    pready <= 0;
                    wbs_sds_adr_i <= {`ADDRUH, paddr};
                    wbs_sds_sel_i <= 4'hf;
                    wbs_sds_we_i <= 0;
                    wbs_sds_cyc_i <= 1;
                    wbs_sds_stb_i <= 1;
                end else begin
                    // read from our block mem
                    pready <= 0;
                    state  <= 15;
                    baddr1 <= paddr - DEVADDR;
                end
            end
        end else if (state == 2) begin
            if (wbs_sds_ack_o) begin
                wbs_sds_we_i  <= 0;
                wbs_sds_cyc_i <= 0;
                wbs_sds_stb_i <= 0;
                $display("sdw ack_o=%x", wbs_sds_ack_o);
                pready <= 1;
                state  <= 0;
            end
        end else if (state == 12) begin
            if (wbs_sds_ack_o) begin
                $display("sdr ack_o=%x dat_o=%x", wbs_sds_ack_o, wbs_sds_dat_o);
                state <= 0;
                prdata <= wbs_sds_dat_o;
                wbs_sds_cyc_i <= 0;
                wbs_sds_stb_i <= 0;
                pready <= 1;
            end
        end else if (state == 5) begin
            pready <= 1;
            state  <= 0;
            bwr1   <= 0;
        end else if (state == 15) begin
            pready <= 1;
            state  <= 0;
            prdata <= bodata1;
        end
    end

    reg [7:0] sdstate;
    wire rd_sel = wbm_sdm_cyc_o && wbm_sdm_stb_o && !wbm_sdm_we_o;
    wire wr_sel = wbm_sdm_cyc_o && wbm_sdm_stb_o && wbm_sdm_we_o;

    task check_sdreq;
        if (wr_sel) begin
            $display("sd wrsel wbm_sdm_adr_o=%x wbm_sdm_dat_o=%x", wbm_sdm_adr_o, wbm_sdm_dat_o);
            if (wbm_sdm_sel_o != 4'hf) begin
                $display("sd wrsel wbm_sdm_sel_o != 4'hf");
                $finish;
            end
            wbm_sdm_ack_i <= 0;
            baddr2 <= wbm_sdm_adr_o;
            bwr2 <= 1;
            bidata2 <= wbm_sdm_dat_o;
            sdstate <= 1;
        end else if (rd_sel) begin
            $display("sd rdsel wbm_sdm_adr_o=%x", wbm_sdm_adr_o);
            if (wbm_sdm_sel_o != 4'hf) begin
                $display("sd rdsel wbm_sdm_sel_o != 4'hf");
                $finish;
            end
            wbm_sdm_ack_i <= 0;
            baddr2 <= wbm_sdm_adr_o;
            sdstate <= 11;
        end else begin
            wbm_sdm_ack_i <= 0;
            sdstate <= 0;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdstate <= 0;
            bidata2 <= 0;
            baddr2 <= 0;
            bwr2 <= 0;
        end else if (sdstate == 0) begin
            check_sdreq;
            // assume wbm_sdm_sel_o = 16'hf
        end else if (sdstate == 1) begin
            bwr2 <= 0;
            wbm_sdm_ack_i <= 1;
            sdstate <= 2;
        end else if (sdstate == 2) begin
            wbm_sdm_ack_i <= 0;
            sdstate <= 0;
        end else if (sdstate == 11) begin
            wbm_sdm_dat_i <= bodata2;
            wbm_sdm_ack_i <= 1;
            sdstate <= 12;
        end else if (sdstate == 12) begin
            wbm_sdm_ack_i <= 0;
            sdstate <= 0;
        end
    end

`ifdef SIM_MODE
    sdModel #(
        .ramdisk (ramdisk),
        .log_file(sd_model_log_file)
    ) sdModelTB0 (
        .sdClk(sd_clk_pad_o),
        .cmd  (sd_cmd),
        .dat  (sd_dat)
    );
`endif

    sdc_controller sd_controller_top_dut (
        .wb_clk_i(wb_clk),
        .wb_rst_i(wb_rst),
        .wb_dat_i(wbs_sds_dat_i),
        .wb_dat_o(wbs_sds_dat_o),
        .wb_adr_i(wbs_sds_adr_i[7:0]),
        .wb_sel_i(wbs_sds_sel_i),
        .wb_we_i(wbs_sds_we_i),
        .wb_stb_i(wbs_sds_stb_i),
        .wb_cyc_i(wbs_sds_cyc_i),
        .wb_ack_o(wbs_sds_ack_o),  // 0 on wb_rst
        .m_wb_adr_o(wbm_sdm_adr_o),
        .m_wb_sel_o(wbm_sdm_sel_o),
        .m_wb_we_o(wbm_sdm_we_o),
        .m_wb_dat_o(wbm_sdm_dat_o),
        .m_wb_dat_i(wbm_sdm_dat_i),
        .m_wb_cyc_o(wbm_sdm_cyc_o),
        .m_wb_stb_o(wbm_sdm_stb_o),
        .m_wb_ack_i(wbm_sdm_ack_i),
        .m_wb_cti_o(wbm_sdm_cti_o),
        .m_wb_bte_o(wbm_sdm_bte_o),
        .sd_cmd_dat_i(sd_cmd),
        .sd_cmd_out_o(cmdIn),
        .sd_cmd_oe_o(sd_cmd_oe),
        .sd_dat_dat_i(sd_dat),
        .sd_dat_out_o(datIn),
        .sd_dat_oe_o(sd_dat_oe),
        .sd_clk_o_pad(sd_clk_pad_o),
        .sd_clk_i_pad(wb_clk),
        .int_cmd(int_cmd),
        .int_data(int_data)
    );

`ifdef laur0
    WB_MASTER_BEHAVIORAL wb_master0 (
        .CLK_I(wb_clk),
        .RST_I(wb_rst),
        .TAG_I(5'h0),  //Not in use
        .TAG_O(),  //Not in use
        .ACK_I(wbs_sds_ack_o),
        .ADR_O(wbs_sds_adr_i),
        .CYC_O(wbs_sds_cyc_i),
        .DAT_I(wbs_sds_dat_o),
        .DAT_O(wbs_sds_dat_i),
        .ERR_I(1'b0),  //Not in use
        .RTY_I(1'b0),  //inactive (1'b0)
        .SEL_O(wbs_sds_sel_i),
        .STB_O(wbs_sds_stb_i),
        .WE_O(wbs_sds_we_i),
        .CAB_O()  //Not in use
    );

    WB_SLAVE_BEHAVIORAL #(
        .wb_memory_file(wb_memory_file)
    ) wb_slave0 (
        .CLK_I(wb_clk),
        .RST_I(wb_rst),
        .ACK_O(wbm_sdm_ack_i),
        .ADR_I(wbm_sdm_adr_o),
        .CYC_I(wbm_sdm_cyc_o),
        .DAT_O(wbm_sdm_dat_i),
        .DAT_I(wbm_sdm_dat_o),
        .ERR_O(),
        .RTY_O(),  //Not in use
        .SEL_I(wbm_sdm_sel_o),
        .STB_I(wbm_sdm_stb_o),
        .WE_I(wbm_sdm_we_o),
        .CAB_I(1'b0)
    );
`endif

endmodule
