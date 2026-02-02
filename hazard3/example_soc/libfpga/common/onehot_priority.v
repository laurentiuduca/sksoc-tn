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

// Input a bitmap. The output will have at most 1 bit set, which will
// be the least-significant set bit of the input.
// e.g. 'b011100 -> 'b000100
// If HIGHEST_WINS is 1, it will instead be the most-significant bit of the output.

`default_nettype none

module onehot_priority #(
    parameter W_INPUT = 8
    //parameter HIGHEST_WINS = 0
) (
    input wire clk,
    input wire rst_n,
    input wire canchange,
    input wire [W_INPUT-1:0] in,
    output reg [W_INPUT-1:0] out
);

    integer i;
    reg deny;
    reg [W_INPUT-1:0] osel, sel;
    wire selchg;
    assign selchg = (sel > 1 && !canchange) || (sel <= 1 && canchange);

    always @(*) begin
        deny = 1'b0;
        if (selchg) begin  //if (HIGHEST_WINS) begin
            for (i = W_INPUT - 1; i >= 0; i = i - 1) begin
                out[i] = in[i] && !deny;
                deny   = deny || in[i];
            end
        end else begin
            for (i = 0; i < W_INPUT; i = i + 1) begin
                out[i] = in[i] && !deny;
                deny   = deny || in[i];
            end
        end
    end

    reg [7:0] gntcnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            osel <= 1;
            sel <= 1;
            gntcnt <= 0;
        end else begin
            if (osel == sel) gntcnt <= gntcnt + 1;
            else gntcnt <= 0;
            osel <= sel;
            /* verilator lint_off CMPCONST */
            //sel <= canchange ? (sel > 1 ? 1 : 2) : out;
            sel  <= out;
            /* verilator lint_on CMPCONST */
        end
    end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
