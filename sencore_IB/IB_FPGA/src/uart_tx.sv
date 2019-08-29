module uart_tx(
	input clk,
	output reg tx,
	input wire cts,
	
	input wire [7:0] data,
	input wire data_valid,
	
	output wire tx_ack
);

// bit divider
reg [4:0] div = '0;

always @(posedge clk) begin
	div <= div + 1;
end
wire bit_en = (div == 0);

// data shift register
reg [8:0] data_sr = 9'h1ff;
assign tx = data_sr[0];

reg [3:0] tx_bit_count = '0;
reg triggered = 1'b0;
reg old_data_valid;

reg tx_ack_reg = 1'b0;
assign tx_ack = tx_ack_reg;

always @(posedge clk) begin
	old_data_valid <= data_valid;
	
	if(data_valid & ~old_data_valid)
		triggered <= 1'b1;
	if(~data_valid)
		tx_ack_reg <= 1'b0;

	if(bit_en) begin
		data_sr <= {1'b1,data_sr[8:1]};
		if(tx_bit_count !=0)
			tx_bit_count <= tx_bit_count - 1;
		if(cts & data_valid & (tx_bit_count == 0) & triggered) begin // new byte
			data_sr <= {data,1'b0};
			tx_bit_count <= 12;
			triggered <= 1'b0;
		end
		if(tx_bit_count == 1)
			tx_ack_reg <= 1'b1;
	end
end

endmodule