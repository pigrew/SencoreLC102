`default_nettype none

module top(
	input wire clk, // 7.3728 MHz
	inout wire [3:0] p2,
	input wire prog,
	
	output wire p2_buf_oe, // goes to the bus driver; always should be low, someone always wants stuff, or maybe with nRST
	output wire p2_buf_dir, // low is reading from bus, high is writing to the bus
	
	//input wire gnd2,
	
	output wire tx, rts,
	input wire rx, cts,
	
	output wire LED
);

wire prog_n;
wire gnd2;
assign prog_n = ~prog;
wire nrst;
GSR GSR_INST (nrst);
assign gnd2 = 1'b0;
sync2 #(.RESET_VALUE(1'b0)) RST_SYNC(.clk, .nrst(~gnd2), .d(1'b1), .q(nrst));

wire clk5, clk10;

wire [3:0] p2o;
wire p2_oe;
assign p2 = (p2_buf_dir) ? p2o : 'z;

//assign p2_buf_oe = 1'b0;
assign p2_buf_oe = ~nrst;

//assign p2_buf_dir = 1'b0;
assign p2_buf_dir = p2_oe & ~prog_n & nrst;

wire [7:0] tx_data;
wire tx_data_available;
wire tx_data_ack_n;
wire led_inv;
ledLatch LED_LATCH(.clk, .nrst, .clk10, .d(prog/*~tx | ~rx*/ ), .q(led_inv));
assign LED = ~led_inv;
//
wire [7:0] rx_data;
/*
always @(posedge clk) begin
	tx_data <= tx_data;
	tx_data_available <= tx_data_available;
	if(tx_data_ack_n && ~tx_data_available) begin
		tx_data <= tx_data + 1;
		tx_data_available <= 1'b1;
	end else if(tx_data_available && ~tx_data_ack_n) begin
		tx_data_available <= 1'b0;
	end
end
*/
wire tx_ack;
wire rx_data_available;
wire talk, talk_ack;

ioexp XPDR (.clk, .nrst,

	// IB pins
	.p2i(p2), .p2o, .prog_n, .p2_oe,
	
	// data UART->IB->Meter
	.tx_data, // p4/p5
	.tx_data_available, // p6.0
	.tx_data_ack_n,
	.talk, .talk_ack,
	
	// data Meter->IB->UART
	.rx_data, .rx_data_available, .tx_ack
);

wire cts_sync, rx_data_available_sync;
sync2 SYNC_CTS(.clk, .nrst, .d(cts), .q(cts_sync));
sync2 SYNC_RX_DATA_AV (.clk, .nrst, .d(rx_data_available), .q(rx_data_available_sync));


uart_tx UART_TX(
	.clk, .clk5, .nrst, .tx(tx), .cts(cts_sync),
	
	.data(rx_data),
	.data_valid(rx_data_available_sync),
	.tx_ack
);

clkdiv CLKDIV (.*);

wire rx_sync;
sync2 SYNC_RX (.clk, .nrst, .d(rx), .q(rx_sync));

uart_rx UART_RX (
	.clk, .nrst,
	
	.rx(rx_sync), .rts(rts),
	
	.data(tx_data),
	.data_valid(tx_data_available),
	.data_ack_n(tx_data_ack_n),
	.talk, .talk_ack
);

endmodule
