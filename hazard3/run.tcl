# gw_sh run.tcl
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7


add_file example_soc/m_topsim.v
add_file example_soc/libfpga/mem/gowin_rpll.v

add_file example_soc/soc/example_soc-dual.v 
add_file example_soc/libfpga/common/reset_sync.v 
add_file example_soc/libfpga/common/fpga_reset.v 
add_file example_soc/libfpga/common/activity_led.v 
add_file hdl/hazard3_core.v 
add_file hdl/hazard3_cpu_1port.v
add_file hdl/hazard3_2cpu.v
add_file hdl/arith/hazard3_alu.v 
add_file hdl/arith/hazard3_branchcmp.v 
add_file hdl/arith/hazard3_mul_fast.v 
add_file hdl/arith/hazard3_muldiv_seq.v 
add_file hdl/arith/hazard3_onehot_encode.v 
add_file hdl/arith/hazard3_onehot_priority.v 
add_file hdl/arith/hazard3_onehot_priority_dynamic.v 
add_file hdl/arith/hazard3_priority_encode.v 
add_file hdl/arith/hazard3_shift_barrel.v 
add_file hdl/hazard3_csr.v 
add_file hdl/hazard3_decode.v 
add_file hdl/hazard3_frontend.v 
add_file hdl/hazard3_instr_decompress.v 
add_file hdl/hazard3_irq_ctrl.v 
add_file hdl/hazard3_pmp.v 
add_file hdl/hazard3_power_ctrl.v 
add_file hdl/hazard3_regfile_1w2r.v 
add_file hdl/hazard3_triggers.v 
add_file hdl/debug/dtm/hazard3_jtag_dtm.v 
add_file hdl/debug/dtm/hazard3_jtag_dtm_core.v 
add_file hdl/debug/cdc/hazard3_apb_async_bridge.v 
add_file hdl/debug/cdc/hazard3_reset_sync.v 
add_file hdl/debug/cdc/hazard3_sync_1bit.v 
add_file hdl/debug/dm/hazard3_dm.v 
add_file example_soc/soc/peri/hazard3_riscv_timer.v 
add_file example_soc/libfpga/peris/uart/uart_mini.v 
add_file example_soc/libfpga/peris/uart/uart_regs.v 
add_file example_soc/libfpga/common/clkdiv_frac.v 
add_file example_soc/libfpga/common/sync_fifo.v 
add_file example_soc/libfpga/cdc/sync_1bit.v 
add_file example_soc/libfpga/peris/spi_03h_xip/spi_03h_xip.v 
add_file example_soc/libfpga/peris/spi_03h_xip/spi_03h_xip_regs.v 
add_file example_soc/libfpga/mem/ahb_cache_readonly.v 
add_file example_soc/libfpga/mem/ahb_cache_writeback.v 
add_file example_soc/libfpga/mem/cache_mem_set_associative.v 
add_file example_soc/libfpga/busfabric/ahbl_crossbar.v 
add_file example_soc/libfpga/busfabric/ahbl_splitter.v 
add_file example_soc/libfpga/busfabric/ahbl_arbiter.v 
add_file example_soc/libfpga/common/onehot_mux.v 
add_file example_soc/libfpga/common/onehot_priority.v 
add_file example_soc/libfpga/busfabric/ahbl_to_apb.v 
add_file example_soc/libfpga/busfabric/apb_splitter.v 
add_file example_soc/libfpga/mem/memory_controller.v 
add_file example_soc/libfpga/mem/memorytn.v 
add_file example_soc/libfpga/mem/memsim.v 
add_file example_soc/libfpga/mem/ahb_laur_mem.v 
add_file example_soc/libfpga/mem/cache_laurwt.v

add_file example_soc/libfpga/mem/maintn.v
add_file example_soc/libfpga/mem/sdram.v

add_file example_soc/libfpga/mem/max7219.v
add_file example_soc/libfpga/mem/clkdivider.v

#add_file example_soc/libfpga/mem/sd_loader.v
#add_file example_soc/libfpga/mem/sd_file_loader.v
#add_file example_soc/libfpga/mem/sd_file_reader.v
#add_file example_soc/libfpga/mem/sd_reader.v
#add_file example_soc/libfpga/mem/sdcmd_ctrl.v

add_file example_soc/libfpga/sd/sd.v
add_file example_soc/libfpga/sd/sd_spi.v
add_file example_soc/libfpga/mem/sdspi_file_reader.v
add_file example_soc/libfpga/mem/sdspi_reader.v
#sd-oc
#add_file example_soc/libfpga/sd/sd-oc.v
#add_file example_soc/libfpga/mem/sd/sdModel.v 
#add_file example_soc/libfpga/sd/bistable_domain_cross.v  
#add_file example_soc/libfpga/sd/generic_fifo_dc_gray.v 
#add_file example_soc/libfpga/sd/sd_cmd_master.v 
#add_file example_soc/libfpga/sd/sd_crc_7.v 
#add_file example_soc/libfpga/sd/sd_wb_sel_ctrl.v 
#add_file example_soc/libfpga/sd/byte_en_reg.v            
#add_file example_soc/libfpga/sd/monostable_domain_cross.v  
#add_file example_soc/libfpga/sd/sd_cmd_serial_host.v  
#add_file example_soc/libfpga/sd/sd_data_master.v       
#add_file example_soc/libfpga/sd/sd_fifo_filler.v 
#add_file example_soc/libfpga/sd/edge_detect.v            
#add_file example_soc/libfpga/sd/sdc_controller.v           
#add_file example_soc/libfpga/sd/sd_controller_wb.v    
#add_file example_soc/libfpga/sd/sd_data_serial_host.v  
#add_file example_soc/libfpga/sd/generic_dpram.v          
#add_file example_soc/libfpga/sd/sd_clock_divider.v         
#add_file example_soc/libfpga/sd/sd_crc_16.v           
#add_file example_soc/libfpga/sd/sd_data_xfer_trig.v

add_file rlsoc.cst

set_option -top_module m_topsim
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -rw_check_on_ram 1
set_option -looplimit 8192

run all
#run syn
#run pnr

