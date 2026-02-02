// modified by Laurentiu-Cristian Duca, 20231028-1235
// author: Laurentiu-Cristian Duca, date: 2023-05-25
// - dual-core support
// spdx license identifier MIT

`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/

module m_maintn #(parameter PRELOAD_FILE = "") (
    
     // these come from cache
     input wire clk,
     input wire rst_x,
     input wire clk_sdram,
     output wire o_init_calib_complete,
     output wire sdram_fail,
       // user interface ports
     input  wire                         i_rd_en,
     input  wire                         i_wr_en,
     input  wire [31:0]                  i_addr,
     input  wire [31:0]                  i_data,
     output wire [31:0]                  o_data,
     output wire                         o_busy,
     input  wire [3:0]                   i_ctrl,
     input  wire [6:0]                   sys_state,
     input  wire [3:0]                   w_bus_cpustate,
     output wire [7:0]                   w_mem_state,

     output wire 			 w_init_done,
     input wire [31:0]             	 d_pc,

    // tang nano 20k SDRAM
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n,            // chip select
    output wire O_sdram_cas_n,           // columns addrefoc select
    output wire O_sdram_ras_n,           // row address select
    output wire O_sdram_wen_n,           // write enable
    inout wire [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus
    output wire [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
    output wire [1:0] O_sdram_ba,        // two banks
    output wire [3:0] O_sdram_dqm,       // 32/4

        input  wire        w_rxd,
        output wire        w_txd,
        output wire [5:0] w_led,
        input wire w_btnl,
        input wire w_btnr,
    	// when sdcard_pwr_n = 0, SDcard power on
    	output wire         sdcard_pwr_n,
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
    	output wire MAX7219_CLK,
    	output wire MAX7219_DATA,
    	output wire MAX7219_LOAD
    );

    // xsim requires declaration before use
    reg r_set_dram_le=0;

    /**********************************************************************************************/
    // bus interface
    wire [31:0] w_dram_addr=i_addr;
    wire [31:0] w_dram_wdata = i_data;
    wire [31:0] w_dram_odata;
    assign o_data = w_dram_odata;
    wire w_dram_we_t = w_init_done ? i_wr_en : 0;
    wire w_dram_busy;
    assign o_busy = w_init_done ? w_dram_busy : 1;
    wire [3:0]   w_dram_ctrl = w_init_done ? i_ctrl : 4'b1111;
    wire w_dram_le = w_init_done ? i_rd_en : r_set_dram_le;

	 
    /**********************************************************************************************/
    reg         r_uart_we = 0;
    reg   [7:0] r_uart_data = 0;
    wire w_tx_ready;
`ifdef LAUR_ON_HAZARD3
    assign w_tx_ready = 0;
`else
    // OUTPUT CHAR
    UartTx UartTx0(clk, rst_x, r_uart_data, r_uart_we, w_txd, w_tx_ready);

`ifdef LAUR_MEM_RB
    // xsim requires declaration before use
    reg r_rb_uart_we=0;
    reg [7:0] r_rb_uart_data;
`endif
    reg r_wait_ready=1;
    reg          r_finish=0;
    always@(posedge clk) begin
        if(w_tx_ready)
            r_wait_ready <= 1;
        else
            r_wait_ready <= 0;
`ifdef LAUR_MEM_RB
	if(r_rb_uart_we) begin
		    r_uart_we <= 1;
		    r_uart_data <= r_rb_uart_data;
    	end else begin 
            r_uart_we   <= 0;
            r_uart_data <= 0;
        end
`endif
    end
`endif

    /**********************************************************************************************/
    reg r_sd_init_we=0;
    reg [31:0] r_sd_init_data=0;

`ifndef SIM_MODE
    wire [31:0] w_sd_init_data;
    wire w_sd_init_we, w_sd_init_done;
    wire [5:0] sd_led_status;
    wire [31:0] w_sdloader_state;
    `ifdef SDSPI
    `ifdef FAT32_SD
    sdspi_file_reader #(
        .FILE_NAME_LEN    ( 11      ),         
        .FILE_NAME        ( "initmem.bin"  )  
    ) u_sd_file_reader (
    .rstn             ( rst_x         ),
    .clk              ( clk            ),
    .filesystem_type  ( filesystem_type      ),  // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
    .file_found       ( file_found        ),  // 0=file not found, 1=file found
    .w_main_init_state(r_init_state), .DATA(w_sd_init_data), .WE(w_sd_init_we), .BOOTDONE(w_sd_init_done), .w_ctrl_state(r_sd_state),
                                .w_reader_status(w_sdloader_state),
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
                                .m_sdspi_status(m_sdspi_status));
	wire file_found;
	wire [1:0] filesystem_type;
	wire [5:0] sd_led_status = ~{w_sd_init_done, file_found, filesystem_type, 2'b00};
    `else
    sdspi_loader sdspi_loader(.clk27mhz(clk), .resetn(rst_x),
        .w_main_init_state(r_init_state), .DATA(w_sd_init_data), .WE(w_sd_init_we), .DONE(w_sd_init_done), 
        .w_ctrl_state(r_sd_state), .w_loader_status(w_sdloader_state),
                                // signals connect to SD controller
                                .psel(m_psel),
                                .penable(m_penable),
                                .pwrite(m_pwrite),
                                .paddr(m_paddr),
                                .pwdata(m_pwdata),
                                .prdata(m_prdata),
                                .pready(m_pready),
                                .pslverr(m_pslverr),
				.sdsbusy(m_sdsbusy),
				.sdspi_status(m_sdspi_status));
    `endif
    `else
    `ifdef FAT32_SD
    sd_file_loader #(.SD_CLK_DIV(`SDCARD_CLK_DIV)) sd_file_loader
      (.clk27mhz(clk), .resetn(rst_x),
        .w_main_init_state(r_init_state), .DATA(w_sd_init_data), .WE(w_sd_init_we), .DONE(w_sd_init_done),
        .w_ctrl_state(r_sd_state),
        .tangled(sd_led_status),
        .sdcard_pwr_n(sdcard_pwr_n), .sdclk(sdclk), .sdcmd(sdcmd), .sdcmd_i(sdcmd_i), .sdcmd_oe(sdcmd_oe),
        .sddat0(sddat0), .sddat1(sddat1), .sddat2(sddat2), .sddat3(sddat3));
    `else
    // sd_loader includes define.vh
    sd_loader /*#(.SD_CLK_DIV(`SDCARD_CLK_DIV))*/ sd_loader(.clk27mhz(clk), .resetn(rst_x), 
        .w_main_init_state(r_init_state), .DATA(w_sd_init_data), .WE(w_sd_init_we), .DONE(w_sd_init_done),
        .w_ctrl_state(r_sd_state),
        .sdcard_pwr_n(sdcard_pwr_n), .sdclk(sdclk), .sdcmd(sdcmd), .sdcmd_i(sdcmd_i), .sdcmd_oe(sdcmd_oe),
        .sddat0(sddat0), .sddat1(sddat1), .sddat2(sddat2), .sddat3(sddat3));
	
    `endif
    `endif
    `ifndef FAT32_SD
    assign sd_led_status = {!w_sd_init_done, 5'b0};
    `endif

    // sd state machine for copying sd to dram
    reg [7:0] r_sd_state=0;
    reg [31:0] diff1=0, diff2=0, setdiff=0;
    always @ (posedge clk) begin
            if(r_sd_state == 0) begin
                if(w_sd_init_we && !w_dram_busy) begin
                    r_sd_init_we <= 1;
                    r_sd_init_data <= w_sd_init_data;
                    r_sd_state <= 1;
                    r_sd_checksum <= r_sd_checksum + w_sd_init_data;
                end
            end else if(r_sd_state == 1) begin
                if(w_dram_busy) begin
                    r_sd_init_we <= 0;
		    r_initaddr3 <= r_initaddr3 + 4;
                    r_sd_state <= 2;
                end
            end else if(r_sd_state == 2) begin
                if(!w_dram_busy) begin
 		    if ((w_sdloader_state[31:10] != r_initaddr3[23:2]) && !setdiff) begin
	                diff1 <= w_sdloader_state;
			diff2 <= r_initaddr3;
			setdiff <= 1;
		    end
                    r_sd_state <= 0;
                end
            end
        if (r_initaddr3 >= `BIN_BBL_SIZE)
            r_bblsd_done <= 1;
    end
`endif

    /**********************************************************************************************/
`ifdef SIM_MODE
    reg  [2:0] r_init_state = 5;
`else
    reg  [2:0] r_init_state = 0;
`endif
    reg  [31:0]  r_initaddr   = 0;
    reg  [31:0]  r_initaddr3  = 0;
    reg  [31:0]  r_checksum = 0, r_sd_checksum=0;
    wire w_pl_init_we=0;
    wire [31:0] w_pl_init_data=0;
    wire [31:0] w_checksum = r_checksum;
    wire [31:0] w_sd_checksum = r_sd_checksum;
    always@(posedge clk) begin
	    r_checksum <= (!rst_x)                      ? 0                             :
                      (!w_init_done & w_pl_init_we) ? r_checksum + w_pl_init_data   :
		               r_checksum;
    end
    /**************************************************************************************************/
    reg          r_bbl_done   = 0;
    reg          r_bblsd_done = 0;
    reg          r_disk_done  = 0;
`ifdef LAUR_MEM_RB
    reg  [31:0]  r_initaddr6  = 0;
`endif
    reg  [31:0]  r_initaddr2 = `BBL_SIZE ; /* initial addres for Disk Drive */

    // Zero init
    wire w_zero_we;
    reg  r_zero_we=0;
    reg  r_zero_done        = 0;
    reg  [31:0]  r_zeroaddr = 0;

`ifdef LAUR_MEM_RB
    // xsim requires declaration before use
    reg r_mem_rb_done=0;
`endif
`ifndef SIM_MODE
    always@(posedge clk) begin
        r_init_state <= (!rst_x) ? 1 :
                      (r_init_state == 0)                ? 1 :
                      (r_init_state == 1 & r_zero_done)  ? 3 : // sd instead of pl
                      (r_init_state == 2 & r_bbl_done)   ? 4 :
                      (r_init_state == 3 & r_bblsd_done) ? 4 :
`ifdef LAUR_MEM_RB
                      (r_init_state == 4 & r_disk_done)  ? 6 :
                      (r_init_state == 6 & r_mem_rb_done)  ? 5 :
`else 
                      (r_init_state == 4 & r_disk_done)  ? 5 :
`endif
                      r_init_state;
    end
`endif // SIM_MODE

    wire [2:0] w_init_state = r_init_state;

    assign w_init_done = (r_init_state == 5);
        
    always@(posedge clk) begin	
`ifdef SIM_MODE
	    if(r_init_state < 1)
		    $display("r_init_state=%d", r_init_state);
`endif
        if(w_pl_init_we & (r_init_state == 2))      r_initaddr      <= r_initaddr + 4;
        if(r_initaddr  >= `BIN_BBL_SIZE)            r_bbl_done      <= 1;
        //if(w_sd_init_we & (r_init_state == 3))      r_initaddr3      <= r_initaddr3 + 4;
        //if(r_initaddr3  >= `BIN_BBL_SIZE)           r_bblsd_done      <= 1;
        if(w_pl_init_we & (r_init_state == 4))      r_initaddr2     <= r_initaddr2 + 4;
        if(r_initaddr2 >= `BBL_SIZE + `BIN_DISK_SIZE)      r_disk_done     <= 1;

    end

`ifdef LAUR_MEM_RB
`ifdef LAUR_MEM_RB_ONLY_CHECK
        reg [31:0] r_rb_delay=0;
`else
	//error, you must also define only check
`endif
	reg [7:0] r_rb_state=0, r_rb_cnt=0;
	reg [31:0] r_rb_data=0, r_verify_checksum=0;
	wire [31:0] w_verify_checksum = r_verify_checksum;
	wire w_checksum_match = (r_verify_checksum == r_checksum);
    wire w_sd_checksum_match = (r_verify_checksum == r_sd_checksum);
    	always@(posedge clk) begin
		if(r_init_state != 6) begin
			r_rb_state <= 0;
			r_set_dram_le <= 0;
		end else begin
			if(r_rb_state == 0) begin // idle
				if(!r_mem_rb_done)
					r_rb_state <= 1;
			end else if(r_rb_state == 1) begin
				if(r_initaddr6 < (`BBL_SIZE + `BIN_DISK_SIZE)) begin
					if(!w_dram_busy) begin
						r_set_dram_le <= 1;
						r_rb_state <= 7;
					end
				end else begin
					r_mem_rb_done <= 1;
					r_rb_state <= 0;
				end
			end else if(r_rb_state == 7) begin // we have sent command
				if(w_dram_busy) begin
					r_set_dram_le <= 0;
					r_rb_state <= 2;
				end
			end else if(r_rb_state == 2) begin // wait ram data
				r_set_dram_le <= 0;
				if(!w_dram_busy) begin
					// we have w_dram_odata
					r_verify_checksum <= r_verify_checksum + w_dram_odata;
					r_rb_data <= w_dram_odata;
`ifdef LAUR_MEM_RB_ONLY_CHECK
`ifdef SIM_MODE
					$display("mem[%x]: %x='%c%c%c%c'", r_initaddr6, w_dram_odata, 
						 w_dram_odata >> 24, (w_dram_odata >> 16) & 8'hff, 
						(w_dram_odata >> 8) & 8'hff, w_dram_odata & 8'hff);
`endif
					r_rb_state <= 20;
					r_rb_delay <= 0;
`else
					r_rb_state <= 3;
`endif
					r_rb_cnt <= 0;
				end
`ifdef LAUR_MEM_RB_ONLY_CHECK
			end else if(r_rb_state == 20) begin
                                if(r_rb_delay < 1) 
                                        r_rb_delay <= r_rb_delay + 1;
                                else begin
                                        r_rb_state <= 0;
                                        r_initaddr6 <= r_initaddr6 + 4;
                                        r_rb_delay <= 0;
                                end	
`endif
			end else if(r_rb_state == 3) begin // send 32 bit data
				if(w_tx_ready)
				   if(r_rb_cnt < 4) begin
						r_rb_cnt <= r_rb_cnt + 1;
						r_rb_uart_data <= r_rb_data[7:0];
						r_rb_data <= {8'h0, r_rb_data[31:8]};
						r_rb_state <= 4;
					end else begin
						r_rb_uart_we <= 0;
						r_initaddr6 <= r_initaddr6 + 4;
						r_rb_state <= 0;
					end
			end else if(r_rb_state == 4) begin // send 1 byte
				r_rb_uart_we <= 1;
				if(!w_tx_ready)
					r_rb_state <= 5;
			end else if(r_rb_state == 5) begin // done sending 1 byte
				r_rb_state <= 3;
				r_rb_uart_we <= 0;
			end
		end
    	end
`endif

    // Zero init
    always@(posedge clk) begin
`ifdef SIM_MAIN
	    r_zero_we <= 0;
	    r_zero_done <= 1;
`else
        if(!w_dram_busy && !r_zero_done && o_init_calib_complete) 
				r_zero_we <= 1;
		  else if(w_dram_busy && r_zero_we) begin
            r_zero_we    <= 0;
            r_zeroaddr <= r_zeroaddr + 4;
        end
        if(r_zeroaddr >= `BIN_SIZE) r_zero_done <= 1;
`endif
    end

`ifdef SIM_MODE
    assign w_zero_we = 0;
`else
`ifdef SIM_MAIN
    assign w_zero_we = 0;
`else
    assign w_zero_we = r_zero_we;
`endif
`endif
    /**********************************************************************************************/
    wire [31:0] w_dram_addr_t   = //(w_dram_addr[31:28]==9) ?
                                   //(w_dram_addr & 32'h3ffffff) + `BBL_SIZE :
                                    w_dram_addr & 32'h3ffffff;
    wire [31:0]  w_dram_addr_t2 =
                    (r_init_state == 1) ? r_zeroaddr     : 
                    (r_init_state == 2) ? r_initaddr     :
                    (r_init_state == 3) ? r_initaddr3    :
`ifdef LAUR_MEM_RB
		            (r_init_state == 6) ? r_initaddr6    :
`endif
                    (r_init_state == 4) ? r_initaddr2    : w_dram_addr_t;
    
    wire [31:0]  w_dram_wdata_t   = (r_init_state == 1) ? 32'b0 :
                                    (r_init_state == 5) ? w_dram_wdata : 
                                    (r_init_state == 3) ? r_sd_init_data : w_pl_init_data;

    wire [3:0]   w_dram_ctrl_t  = (!w_init_done) ? 4'b1111 : w_dram_ctrl;
    /**********************************************************************************************/

`ifdef LAUR_MEM_RB
    wire w_wr_en =                 (r_init_state == 6) ? 0 :
				                    w_zero_we || w_pl_init_we || r_sd_init_we || w_dram_we_t;
`else
`ifdef SIM_MODE
        wire w_wr_en =              w_dram_we_t;
`else
    wire w_wr_en =                  w_zero_we || w_pl_init_we || r_sd_init_we || w_dram_we_t;
`endif
`endif

    wire w_late_refresh;
    DRAM_conRV #(.PRELOAD_FILE(PRELOAD_FILE))
    dram_con (
                               // user interface ports
`ifdef LAUR_MEM_RB
                               .i_rd_en(w_dram_le | r_set_dram_le),
`else
                               .i_rd_en(w_dram_le),
`endif
                               .i_wr_en(w_wr_en),
                               .i_addr(w_dram_addr_t2),
                               .i_data(w_dram_wdata_t),
                               .o_data(w_dram_odata),
                               .o_busy(w_dram_busy),
                               .i_ctrl(w_dram_ctrl_t),
                               .sys_state(r_init_state),
                               .w_bus_cpustate(w_bus_cpustate),
                               .mem_state(w_mem_state),

                               .clk(clk),
                               .rst_x(rst_x),
                               .clk_sdram(clk_sdram),
                               .o_init_calib_complete(o_init_calib_complete),
                               .sdram_fail(sdram_fail),
                               `ifdef TN_DRAM_REFRESH
                               .r_late_refresh(w_late_refresh),
                               `endif

                                `ifdef SIM_MODE
                                .w_mtime()
                                `else
                                .O_sdram_clk(O_sdram_clk),
                               .O_sdram_cke(O_sdram_cke),
                               .O_sdram_cs_n(O_sdram_cs_n),            // chip select
                               .O_sdram_cas_n(O_sdram_cas_n),           // columns address select
                               .O_sdram_ras_n(O_sdram_ras_n),           // row address select
                               .O_sdram_wen_n(O_sdram_wen_n),           // write enable
                               .IO_sdram_dq(IO_sdram_dq),       // 32 bit bidirectional data bus
                               .O_sdram_addr(O_sdram_addr),     // 11 bit multiplexed address bus
                               .O_sdram_ba(O_sdram_ba),        // two banks
                               .O_sdram_dqm(O_sdram_dqm)       // 32/4
                               `endif
                               );
    /**********************************************************************************************/

    // debug on display
    `ifndef SIM_MODE
    wire clkdiv;
    wire [31:0] data_vector;
    max7219 max7219(.clk(clk), .clkdiv(clkdiv), .reset_n(rst_x), .data_vector(data_vector),
            .clk_out(MAX7219_CLK),
            .data_out(MAX7219_DATA),
            .load_out(MAX7219_LOAD)
        );
    clkdivider cd(.clk(clk), .reset_n(rst_x), .n(21'd100), .clkdiv(clkdiv));

    assign data_vector = (w_btnr == 0 && w_btnl == 0) ? w_sdloader_state : //{5'b0, r_init_state[2:0], r_initaddr3[23:0]} 
    			w_btnr ? diff2 : //w_sd_checksum :
	    		w_btnl ? diff1 : {m_sdspi_status}; // {24'h0, 5'b0, r_init_state}; 

    
    assign w_led = (w_btnl == 0 && w_btnr == 0) ? 
                        ~ {w_sd_checksum_match, r_mem_rb_done, w_sd_init_done, 
                        w_init_done, r_zero_done, o_init_calib_complete & !sdram_fail & !w_late_refresh} :
                        sd_led_status;
    `endif
endmodule
    /**********************************************************************************************/

