vlog -lint ../src/*.sv
vsim tb_top

add wave tb_top/clk tb_top/p2
add wave tb_top/TOP/*
add wave tb_top/TOP/XPDR/p6
add wave tb_top/TOP/XPDR/p7
#add wave -group UART tb_top/TOP/UART_TX/*
add wave -group UART_RX tb_top/TOP/UART_RX/*
run 500us
