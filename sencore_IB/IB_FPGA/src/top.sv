module top(
	input wire clk, // 7.3728 MHz
	inout wire [3:0] p2,
	input wire prog_n,
	
	output wire p2_buf_oe, // goes to the bus driver; always should be low, someone always wants stuff
	output wire p2_buf_dir, // low is reading from bus, high is writing to the bus
	
	output wire tx, rts,
	input wire rx, cts,
	
	output wire LED
);

wire [3:0] p2o;
wire p2_oe;
assign p2_buf_dir = p2_oe & ~prog_n;
assign p2 = (p2_buf_dir) ? p2o : 'z;
assign p2_buf_oe = 1'b0;

wire [7:0] tx_data;
wire tx_data_available;
wire tx_data_ack_n;
assign LED = ~tx | ~rx | ~cts | ~rts;
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
ioexp XPDR (.clk,

	// IB pins
	.p2i(p2), .p2o, .prog_n, .p2_oe,
	
	// data UART->IB->Meter
	.tx_data, // p4/p5
	.tx_data_available, // p6.0
	.tx_data_ack_n,
	
	// data Meter->IB->UART
	.rx_data, .rx_data_available, .tx_ack
);


wire cts_sync, rx_data_available_sync;
sync2 SYNC_CTS(.clk, .d(cts), .q(cts_sync));
sync2 SYNC_RX_DATA_AV (.clk, .d(rx_data_available), .q(rx_data_available_sync));

uart_tx UART_TX(
	.clk, .tx, .cts(cts_sync),
	
	.data(rx_data),
	.data_valid(rx_data_available_sync),
	.tx_ack
);


wire rx_sync;
sync2 SYNC_RX (.clk, .d(rx), .q(rx_sync));

uart_rx UART_RX (
	.clk,
	
	.rx(rx_sync), .rts,
	
	.data(tx_data),
	.data_valid(tx_data_available),
	.data_ack_n(tx_data_ack_n)
);


endmodule