

module fpga_top (
    input  wire         clk27mhz,
    // rstn active-low, You can re-read SDcard by pushing the reset button.
    input  wire         w_btnl,
    input wire          w_btnr,
    // signals connect to SD bus
    output wire         sclk,
    inout               mosi,
    input  wire         miso,
    output wire         cs,
    // 16 bit led to show the status of SDcard
    output wire [5:0]  led,
    // UART tx signal, connected to host-PC's UART-RXD, baud=115200
    output wire         uart_tx,

        // display
        output wire MAX7219_CLK,
        output wire MAX7219_DATA,
        output wire MAX7219_LOAD
);


`define BLOCKSIZE 512

reg resetn=0;
reg [31:0] rcnt=0;
always @ (posedge clk27mhz)
	if(rcnt < 10000)
		rcnt <= rcnt+1;
	else 
		resetn <= 1;

reg       outen;
reg [7:0] outbyte;
reg [7:0] firstout=0;

reg [31:0] scnt=0;

reg [7:0] m[0:`BLOCKSIZE-1];
integer i;
initial for(i=0; i < `BLOCKSIZE; i=i+1) m[i] <= 0;
reg mw=0, mr=0, serwr=0;
reg [7:0] mdata=0, serdata=0;
reg [7:0] mout=0;
reg [31:0] maddr=0;
always @ (posedge clk27mhz) begin
	if(mw)
		m[maddr] <= mdata;
	mout <= m[maddr];
end
//assign mout = m[maddr];

//sd state machine
reg [7:0] state=0, errstate=0;
reg [31:0] sdsbaddr=0, oecnt=0;
reg sdsrd=0, sdswr=0; 
wire sdserror, sdsbusy;
reg noerror=1;
reg [2:0] errorcode=0;
wire [2:0] sdserror_code;
reg [7:0] sdsdin=0, firstdin=0;
reg sdsdin_valid=0;
wire sdsdin_taken;
wire [7:0] sdsdout;
wire sdsdout_avail;
reg sdsdout_taken=0;
wire [1:0] state_o;
wire [7:0] sdsfsm_o;
always @ (posedge clk27mhz or negedge resetn) begin
    	if(~resetn) begin
        	state <= 0;
		sdsbaddr <= 0;
	end else if(state == 0) begin
		if(sdsbusy == 0) 
			state <= 1;
    	end else if(state == 1) begin
		sdsrd <= 1;
		oecnt <= 0;
		//sdsbaddr <= 0;
		state <= 2;
	end else if(state == 2) begin
		if(sdsdout_avail && !sdserror) begin
			//sdsrd <= 0;
			outbyte <= sdsdout;
			sdsdout_taken <= 1;
			state <= 3;
		end
	end else if(state == 3) begin
	          if(oecnt < `BLOCKSIZE) begin
			oecnt <= oecnt + 1;
                	mw <= 1;
                	maddr <= oecnt;
                	mdata <= outbyte;
                	state <= 4;
		  end
        end else if(state == 4) begin
		mw <= 0;
		if(!sdsdout_avail) begin
			sdsdout_taken <= 0;
			if(oecnt < `BLOCKSIZE) begin
				state <= 2;
				sdsrd <= 1;
			end else begin
				sdsrd <= 0;
				scnt <= 0;
				if(sdsbusy == 0) begin
					// send to uart
					state <= 5;
					scnt <= 0;
				end
			end
		end
	end else if(state == 5) begin
          	if((oecnt >= `BLOCKSIZE) && (scnt < `BLOCKSIZE)) begin
                        // send to serial.
                        maddr <= scnt;
                        state <= 26;
	  	end else begin
			// write block
			if(sdsbaddr < 1) begin
				state <= 10;
	                        oecnt <= 0;
				sdsbaddr <= sdsbaddr + 1;
			end
	  	end
        end else if(state == 26) begin
		state <= 6;
	end else if(state == 6) begin
                if(tre_o) begin
			if(mout && firstdin == 0)
				firstdin <= mout;
                        scnt <= scnt + 1;
                        serdata <= mout;
                        serwr <= 1;
                        state <= 7;
                end
        end else if(state == 7) begin
                if(!tre_o) begin
                        serwr <= 0;
                        state <= 8;
                end
        end else if(state == 8) begin
                if(tre_o)
                        state <= 5;
        end else if(state == 10) begin
		if(oecnt < `BLOCKSIZE) begin
	        	maddr <= oecnt;
			state <= 16;
		end else begin
			sdswr <= 0;
			if(sdsbusy == 0) begin
				oecnt <= 0;
				state <= 0;
			end
		end
	end else if(state == 16) begin
		// read mem
		state <= 11;
	end else if(state == 11) begin
		sdswr <= 1;
		sdsdin <= mout; // laur
		sdsdin_valid <= 1;
                state <= 12;
        end else if(state == 12) begin
		if(sdsdin_taken == 1) begin
			//sdswr <= 0;
			sdsdin_valid <= 0;
			state <= 13;
		end
	end else if(state == 13) begin
		if(sdsdin_taken == 0) begin
			oecnt <= oecnt + 1;
			state <= 10;
		end
	end
end
always @ (posedge clk27mhz or negedge resetn) begin
        if(~resetn) begin
                noerror <= 1;
		errorcode <= 0;
        end else if(sdserror/* && noerror*/) begin
		//noerror <= 0;
		errorcode <= sdserror_code;
		errstate <= state;
	end
end

//----------------------------------------------------------------------------------------------------
// send file content to UART
//----------------------------------------------------------------------------------------------------
wire tre_o;
UartTx tx(.CLK(clk27mhz), .RST_X(resetn), .DATA(serdata), .WE(serwr), .TXD(uart_tx), .READY(tre_o));

    /**********************************************************************************************/

    // debug on display
    wire clkdiv;
    wire [31:0] data_vector;
    max7219 max7219(.clk(clk27mhz), .clkdiv(clkdiv), .reset_n(resetn), .data_vector(data_vector),
            .clk_out(MAX7219_CLK),
            .data_out(MAX7219_DATA),
            .load_out(MAX7219_LOAD)
        );
    clkdivider cd(.clk(clk27mhz), .reset_n(resetn), .n(21'd100), .clkdiv(clkdiv));

    assign data_vector = (w_btnr == 0 && w_btnl == 0) ? {{firstdin, sdsbaddr[3:0], {1'b0, sdserror_code}}, oecnt[15:0]} : 
	    w_btnr ? {{errstate[3:0], 3'd0, sdsbusy, state}, scnt[15:0]} : {tre_o, maddr[14:0], mout, serdata};
    assign led = (w_btnl == 0 && w_btnr == 0) ? ~(state[5:0]) : ~sdsbaddr[3:0];
        //~((scnt >> 8) & tre_o);

sd_controller /*#(.WRITE_TIMEOUT(1))*/ sdc (
                        .clk(clk27mhz), // twice the SPI clk
                        .reset(!resetn),

                        .cs(cs),
                        .mosi(mosi),
                        .miso(miso),
                        .sclk(sclk),
                        .card_present(1'b1),
                        .card_write_prot(1'b0),

                        .rd(sdsrd),// Should latch maddr on rising edge
                        .rd_multiple(1'b0), // Should latch maddr on rising edge
                        .wr(sdswr), // Should latch maddr on rising edge
                        .wr_multiple(1'b0), // Should latch maddr on rising edge
                        .addr(sdsbaddr),
                        .erase_count(8'h0), // 8'h2 for multiple write only

                        .sd_error(sdserror), // if an error occurs, reset on next RD or WR
                        .sd_busy(sdsbusy), // '0' if a RD or WR can be accepted
                        .sd_error_code(sdserror_code), //

                        .din(sdsdin),
                        .din_valid(sdsdin_valid),
                        .din_taken(sdsdin_taken),

                        .dout(sdsdout),
                        .dout_avail(sdsdout_avail),
                        .dout_taken(sdsdout_taken),

                        // Debug stuff
                        .sd_type(state_o),
                        .sd_fsm(sdsfsm_o)
        );


endmodule
