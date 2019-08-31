vlog -lint ../src/*.sv
vsim -L machxo2_vlg -L PMI_work work.tb_top

add wave tb_top/clk tb_top/p2_bus tb_top/p2_mcu tb_top/p2_fpga
add wave tb_top/TOP/*
add wave tb_top/TOP/XPDR/p6
add wave tb_top/TOP/XPDR/p7
#add wave -group UART tb_top/TOP/UART_TX/*
add wave -group UART_RX tb_top/TOP/UART_RX/*
run 500us
