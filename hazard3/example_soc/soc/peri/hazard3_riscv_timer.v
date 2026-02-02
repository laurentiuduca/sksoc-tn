// Modified by Laurentiu Cristian Duca, 2025/08
// spdx license identifier - apache 2

/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

`default_nettype none

// Basic implementation of standard 64-bit RISC-V timer with 32-bit APB.

// TICK_IS_NRZ = 1: tick is an NRZ signal that is asynchronous to clk.
// TICK_IS_NRZ = 0: tick is a level-sensitive signal that is synchronous to clk.

module hazard3_riscv_timer #(
    parameter TICK_IS_NRZ = 0,
    `include "hazard3_config.vh"
) (
    input wire clk,
    input wire rst_n,

    input  wire [      15:0] paddr,
    input  wire              psel,
    input  wire              penable,
    input  wire              pwrite,
    input  wire [      31:0] pwdata,
    output reg  [      31:0] prdata,
    output reg               pready,
    output wire              pslverr,
    input  wire [W_DATA-1:0] phartid,
    input  wire [W_ADDR-1:0] pd_pc,

    input wire dbg_halt,
    input wire tick,

    output reg [N_HARTS-1:0] soft_irq,
    output reg [N_HARTS-1:0] timer_irq
);

    localparam ADDR_IPI = 16'h0000;
    localparam ADDR_MTIME = 16'h0008;
    localparam ADDR_MTIMEH = 16'h000c;
    localparam ADDR_MTIMECMP = 16'h0010;
    localparam ADDR_MTIMECMPH = 16'h0014;

    // ----------------------------------------------------------------------------
    // Timer tick logic
    wire tick_event;
    assign tick_event = tick;

    wire tick_now = tick_event && !dbg_halt;

    // ----------------------------------------------------------------------------
    // Counter registers

    wire bus_write = pwrite && psel && penable;
    wire bus_read = !pwrite && psel && penable;

    integer tcnt = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            //ctrl_en <= 1'b1;
            soft_irq <= 0;
            tcnt <= 0;
        end else begin
            if (bus_write && paddr == ADDR_IPI && !state) begin
                // nuttx sends ipi at this addr
`ifdef dbgstart
                $display(
                    "\t h%1x pc=%x iowrite && paddr == ADDR_IPI %x && pwdata=%x soft_irq was %x t%d",
                    phartid, pd_pc, paddr, pwdata, soft_irq, $time);
`endif
                if (pwdata == 0) soft_irq[0] <= 0;
                else soft_irq[0] <= 1;
            end else if (bus_write && paddr == (ADDR_IPI + 4) && !state) begin
                // laur - nuttx sends ipi at this addr
		if(N_HARTS > 1) begin
`ifdef dbgstart
	                $display(
        	            "\t h%1x pc=%x iowrite && paddr == ADDR_IPI+4 %x && pwdata=%x soft_irq was %x t%d",
                	    phartid, pd_pc, paddr, pwdata, soft_irq, $time);
`endif
	                if (pwdata == 0) soft_irq[N_HARTS-1] <= 0;
        	        else soft_irq[N_HARTS-1] <= 1;
		end
            end
            tcnt <= tcnt + 1;
        end
    end

    reg [63:0] mtime;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 64'h0;
        end else begin
            if (tick_now) mtime <= mtime + 1'b1;
            if (bus_write && paddr == ADDR_MTIME) mtime[31:0] <= pwdata;
            if (bus_write && paddr == ADDR_MTIMEH) mtime[63:32] <= pwdata;
        end
    end

    // mtimecmp is stored inverted for minor LUT savings on iCE40
    reg [63:0] mtimecmp0, mtimecmp1;
    wire [64:0] cmp_diff0 = {1'b0, mtime} + {1'b0, mtimecmp0} + 65'd1;
    wire [64:0] cmp_diff1 = {1'b0, mtime} + {1'b0, mtimecmp1} + 65'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtimecmp0 <= 64'h0;
            mtimecmp1 <= 64'h0;
            timer_irq <= 2'b0;
        end else begin
            if (bus_write && paddr == ADDR_MTIMECMP) begin
                mtimecmp0[31:0] <= ~pwdata;
            end else if (bus_write && paddr == ADDR_MTIMECMPH) begin
                mtimecmp0[63:32] <= ~pwdata;
            end
            if (bus_write && paddr == ADDR_MTIMECMP + 8) begin
                mtimecmp1[31:0] <= ~pwdata;
            end else if (bus_write && paddr == ADDR_MTIMECMPH + 8) begin
                mtimecmp1[63:32] <= ~pwdata;
            end
            timer_irq <= {cmp_diff1[64], cmp_diff0[64]};
        end
    end

    always @(*) begin
        case (paddr)
            ADDR_IPI:            prdata = {31'd0, soft_irq[0]};
            ADDR_IPI + 4:        prdata = (N_HARTS > 1) ? {31'd0, soft_irq[N_HARTS-1]} : 32'h0;
            ADDR_MTIME:          prdata = mtime[31:0];
            ADDR_MTIMEH:         prdata = mtime[63:32];
            ADDR_MTIMECMP:       prdata = ~mtimecmp0[31:0];
            ADDR_MTIMECMPH:      prdata = ~mtimecmp0[63:32];
            ADDR_MTIMECMP + 8:   prdata = ~mtimecmp1[31:0];
            ADDR_MTIMECMPH + 12: prdata = ~mtimecmp1[63:32];
            default:             prdata = 32'h0;
        endcase
    end

    reg [1:0] state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pready <= 0;
            state  <= 0;
        end else if (state == 0) begin
            if (bus_read) begin
                pready <= 1;
                state  <= 1;
            end else if (bus_write) begin
                pready <= 1;
                state  <= 2;
            end
        end else if (state == 1) begin
            if (!bus_read) state <= 0;
            pready <= 0;
        end else if (state == 2) begin
            if (!bus_write) state <= 0;
            pready <= 0;
        end
    end
    //assign pready = 1'b1;
    assign pslverr = 1'b0;

endmodule

`ifndef YOSYS
`default_nettype none
`endif
