module uart_tx(
	input wire clk,
	input wire nrst,
	output reg tx,
	input wire cts,
	
	input wire [7:0] data,
	input wire data_valid,
	
	output wire tx_ack
);

localparam DIV_WIDTH = 5;
localparam TX_BIT_COUNT_WIDTH = 4;

// bit divider
reg [DIV_WIDTH-1:0] div;

always @(posedge clk or negedge nrst) begin
	if(~nrst) begin
		div <= '0;
	end else begin
		div <= div + {{(DIV_WIDTH-1){1'b0}},1'b1};
	end
end
wire bit_en = (div == 0);

// data shift register
reg [8:0] data_sr;
assign tx = data_sr[0];

reg [TX_BIT_COUNT_WIDTH-1:0] tx_bit_count;
reg triggered;
reg old_data_valid;

reg tx_ack_reg;
assign tx_ack = tx_ack_reg;

always_ff @(posedge clk) begin
	if (~nrst) begin
		old_data_valid <= '0;
		tx_bit_count <= '0;
		tx_ack_reg <= 1'b0;
		triggered <= 1'b0;
		data_sr <= 9'h1ff;
	end else begin
		old_data_valid <= data_valid;
		
		if(data_valid & ~old_data_valid)
			triggered <= 1'b1;
		if(~data_valid)
			tx_ack_reg <= 1'b0;

		if(bit_en) begin
			data_sr <= {1'b1,data_sr[8:1]};
			if(tx_bit_count !=0)
				tx_bit_count <= tx_bit_count - {{(TX_BIT_COUNT_WIDTH-1){1'b0}},1'b1};
			if(cts & data_valid & (tx_bit_count == 0) & triggered) begin // new byte
				data_sr <= {data,1'b0};
				tx_bit_count <= 12;
				triggered <= 1'b0;
			end
			if(tx_bit_count == 1)
				tx_ack_reg <= 1'b1;
		end
	end
end

endmodule