#from the ulx3s synth script
#HAZARD3DIR = /home/laur/lucru/cn/riscv/hazard3
HAZARD3DIR = .
HDL=$(HAZARD3DIR)/hdl
HDLDEBUG=$(HDL)/debug
HDLPERI=$(HAZARD3DIR)/example_soc/soc/peri
HDLLF=$(HAZARD3DIR)/example_soc/libfpga
HDLLFCOMMON=$(HDLLF)/common
HDLLFPERI=$(HDLLF)/peris
HDLSD=$(HDLLF)/sd

TOPSOURCE=$(HAZARD3DIR)/example_soc/m_topsim.v
OTHERSOURCE= $(HAZARD3DIR)/example_soc/soc/example_soc-dual.v $(HDLLFCOMMON)/reset_sync.v $(HDLLFCOMMON)/fpga_reset.v $(HDLLFCOMMON)/activity_led.v $(HDL)/hazard3_core.v $(HDL)/hazard3_2cpu.v $(HDL)/hazard3_cpu_1port.v $(HDL)/arith/hazard3_alu.v $(HDL)/arith/hazard3_branchcmp.v $(HDL)/arith/hazard3_mul_fast.v $(HDL)/arith/hazard3_muldiv_seq.v $(HDL)/arith/hazard3_onehot_encode.v $(HDL)/arith/hazard3_onehot_priority.v $(HDL)/arith/hazard3_onehot_priority_dynamic.v $(HDL)/arith/hazard3_priority_encode.v $(HDL)/arith/hazard3_shift_barrel.v $(HDL)/hazard3_csr.v $(HDL)/hazard3_decode.v $(HDL)/hazard3_frontend.v $(HDL)/hazard3_instr_decompress.v $(HDL)/hazard3_irq_ctrl.v $(HDL)/hazard3_pmp.v $(HDL)/hazard3_power_ctrl.v $(HDL)/hazard3_regfile_1w2r.v $(HDL)/hazard3_triggers.v $(HDL)/debug/dtm/hazard3_jtag_dtm.v $(HDL)/debug/dtm/hazard3_jtag_dtm_core.v $(HDL)/debug/cdc/hazard3_apb_async_bridge.v $(HDL)/debug/cdc/hazard3_reset_sync.v $(HDL)/debug/cdc/hazard3_sync_1bit.v $(HDL)/debug/dm/hazard3_dm.v $(HDLPERI)/hazard3_riscv_timer.v $(HDLLFPERI)/uart/uart_mini.v $(HDLLFPERI)/uart/uart_regs.v $(HDLLFCOMMON)/clkdiv_frac.v $(HDLLFCOMMON)/sync_fifo.v $(HDLLF)/cdc/sync_1bit.v $(HDLLFPERI)/spi_03h_xip/spi_03h_xip.v $(HDLLFPERI)/spi_03h_xip/spi_03h_xip_regs.v $(HDLLF)/busfabric/ahbl_crossbar.v $(HDLLF)/busfabric/ahbl_splitter.v $(HDLLF)/busfabric/ahbl_arbiter.v $(HDLLFCOMMON)/onehot_mux.v $(HDLLFCOMMON)/onehot_priority.v $(HDLLF)/busfabric/ahbl_to_apb.v $(HDLLF)/busfabric/apb_splitter.v 
LAURMEMWB=$(HDLLF)/mem/memory_controller.v $(HDLLF)/mem/memorytn.v $(HDLLF)/mem/memsim.v $(HDLLF)/mem/ahb_laur_mem.v $(HDLLF)/mem/cache_laurwb.v $(HDLLF)/mem/maintn.v $(HDLLF)/mem/sdram.v $(HDLLF)/mem/max7219.v $(HDLLF)/mem/clkdivider.v $(HDLLF)/mem/sd_loader.v $(HDLLF)/mem/sd_file_loader.v $(HDLLF)/mem/sd_file_reader.v $(HDLLF)/mem/sd_reader.v $(HDLLF)/mem/sdcmd_ctrl.v
LAURMEMWT=$(HDLLF)/mem/memory_controller.v $(HDLLF)/mem/memorytn.v $(HDLLF)/mem/memsim.v $(HDLLF)/mem/ahb_laur_mem.v $(HDLLF)/mem/cache_laurwt.v $(HDLLF)/mem/maintn.v $(HDLLF)/mem/sdram.v $(HDLLF)/mem/max7219.v $(HDLLF)/mem/clkdivider.v $(HDLLF)/mem/sdspi_loader.v $(HDLLF)/mem/sdspi_file_reader.v $(HDLLF)/mem/sdspi_reader.v 
LUKEMEM=$(HDLLF)/mem/sram_sync.v $(HDLLF)/mem/ahb_sync_sram.v 
SDSPI=$(HDLSD)/sd.v $(HDLSD)/sd_spi.v
SDOC=$(HDLSD)/sd-oc.v $(HDLSD)/sdModel.v $(HDLSD)/bistable_domain_cross.v  $(HDLSD)/generic_fifo_dc_gray.v $(HDLSD)/sd_cmd_master.v $(HDLSD)/sd_crc_7.v $(HDLSD)/sd_wb_sel_ctrl.v $(HDLSD)/byte_en_reg.v            $(HDLSD)/monostable_domain_cross.v  $(HDLSD)/sd_cmd_serial_host.v  $(HDLSD)/sd_data_master.v       $(HDLSD)/sd_fifo_filler.v $(HDLSD)/edge_detect.v            $(HDLSD)/sdc_controller.v           $(HDLSD)/sd_controller_wb.v    $(HDLSD)/sd_data_serial_host.v  $(HDLSD)/generic_dpram.v          $(HDLSD)/sd_clock_divider.v         $(HDLSD)/sd_crc_16.v           $(HDLSD)/sd_data_xfer_trig.v


# Verilator
TOPMODULE = m_topsim
VERILATOR  = verilator 
VERIFLAGS += --public --top-module $(TOPMODULE) --clk clk
VERIFLAGS += --x-assign 0 --x-initial 0 --timing
VERIFLAGS += --threads 1 -O2 
#VERIFLAGS += --threads 3 -DVL_THREADED -O2
VERIFLAGS += -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-COMBDLY -Wno-LATCH
VERIFLAGS += -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-INITIALDLY -Wno-MULTIDRIVEN
VERIFLAGS += --exe sim.cpp --cc --trace
VERIFLAGS2 = $(VERIFLAGS) -I$(HDL) -I$(HDLLF)/.. -I$(HDLSD)

.PHONY: all clean
all: veriwt

SYNTH_CMD += read_verilog -I $(HDL) -DCONFIG_HEADER="config_default.vh" ${TOPSOURCE} ${OTHERSOURCE};
SYNTH_CMD += hierarchy -top $(TOPMODULE);
SYNTH_CMD += write_cxxrtl dut.cpp
BUILD_DIR = example_soc_log
dut.cpp: 
	mkdir -p $(BUILD_DIR)
	yosys -p '$(SYNTH_CMD)' 2>&1 > $(BUILD_DIR)/cxxrtl.log
tb.out:
	$(CLANGXX) -O3 -std=c++14 $(addprefix -D,$(CDEFINES) -I $(shell yosys-config --datdir)/include/backends/cxxrtl/runtime -I $(BUILD_DIR) main.cpp -o tb.out

clean:
	rm -f simple.vvp *.vcd *.out result.txt simv ucli.key vcs-result.txt log.txt diff.txt final_mem.txt log.txt.gz trace.txt
	rm -rf simv.daidir csrc
	rm -rf obj_dir
	rm -rf synth.vg impl serialout.txt ftn.txt *out stip*.txt
	rm -rf laur2.txt log*txt ./a.out
	rm -rf xsim*.* xelab*.* xvlog*.* sd_model.log
	rm -f init_kernel.txt fh fl fout cl ch cr impl dump.vcd
	rm -f *vg *json yosys.txt
	rm -f initmem.bin simsd.fat32

veriwb:
	${VERILATOR} ${VERIFLAGS2} ${TOPSOURCE} ${OTHERSOURCE} ${LAURMEMWB} ${SDSPI}
	make -j -C obj_dir -f V$(TOPMODULE).mk V$(TOPMODULE)
	cp obj_dir/Vm_topsim simv
	./simv
verio:
	${VERILATOR} ${VERIFLAGS2} ${TOPSOURCE} ${OTHERSOURCE} ${LUKEMEM} ${SDSPI}
	make -j -C obj_dir -f V$(TOPMODULE).mk V$(TOPMODULE)
	cp obj_dir/Vm_topsim simv
	./simv
veriwt:
	${VERILATOR} ${VERIFLAGS2} ${TOPSOURCE} ${OTHERSOURCE} ${LAURMEMWT} ${SDSPI}
	make -j -C obj_dir -f V$(TOPMODULE).mk V$(TOPMODULE)
	cp obj_dir/Vm_topsim simv
	./simv
icarus:
	iverilog ${TOPSOURCE} ${OTHERSOURCE}  ${LAURMEMWT} ${SD} -DICARUS -I$(HDL) -I$(HDLSD) -Iexample_soc
       #	-g2005-sv
	./a.out

vivado:
	@echo "**** Vivado Simulator "
	xvlog -sv -d ICARUS -i $(HDL) -i $(HDLSD) -i example_soc ${TOPSOURCE} ${OTHERSOURCE} ${LAURMEMWT} ${SD}
	xelab $(TOPMODULE) -timescale 1ns/100ps
	xsim $(TOPMODULE) -R

gwsynth:
	time gw_sh run.tcl

BOARD=tangnano20k
FAMILY=GW2A-18C
DEVICE=GW2AR-LV18QN88C8/I7
yosys:
	yosys -p "read_verilog -I$(HDL) -I$(HDLSD) -Iexample_soc ${TOPSOURCE} ${OTHERSOURCE} ${LAURMEMWT} ${SDSPI}; synth_gowin -top ${TOPMODULE} -vout ${TOPMODULE}.vg -json ${TOPMODULE}.json"
nextpnr:
	nextpnr-himbaechel --json ${TOPMODULE}.json --freq 27 --write ${TOPMODULE}_pnr.json --device ${DEVICE} --vopt family=${FAMILY} --vopt cst=rlsoc.cst.nextpnr
	gowin_pack -d ${FAMILY} -o ${TOPMODULE}.fs ${TOPMODULE}_pnr.json

