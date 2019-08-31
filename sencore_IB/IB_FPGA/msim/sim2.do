vlog -lint ../src/tb*.sv
vlog ../impl1/sencoreib_impl1_mapvo.vo
vsim -L machxo2_vlg -L PMI_work work.tb_top  -sdftyp /tb_top/TOP=../impl1/sencoreib_impl1_mapvo.sdf

configure wave -signalnamewidth 1

#add wave tb_top/clk tb_top/p2_bus tb_top/p2_mcu tb_top/p2_fpga
add wave sim:/tb_top/TOP/GSR_INST/GSRNET
add wave tb_top/TOP/PUR_INST/PURNET
add wave tb_top/*
add wave tb_top/TOP/nrst
#add wave tb_top/TOP/XPDR/p6
#add wave tb_top/TOP/XPDR/p7
#add wave -group UART tb_top/TOP/UART_TX/*
#add wave -group UART_RX tb_top/TOP/UART_RX/*
run 500us
