module ioexp(
	input wire clk, // 8 MHz
	input wire nrst,
	
	// IB pins
	input wire [3:0] p2i,
	output reg [3:0] p2o,
	input wire prog_n,
	output wire p2_oe,
	
	// data UART->IB->Meter
	input wire [7:0] tx_data, // p4/p5
	input wire tx_data_available, // p6.0
	output wire tx_data_ack_n,
	
	// data Meter->IB->UART
	output reg [7:0] rx_data,
	input wire tx_ack, // ~p6.2
	output wire rx_data_available// p7.2
);

reg w_en_reg = 1'b0;

reg [3:0] p7 = 4'hF;

assign tx_data_ack_n = p7[1];
assign rx_data_available = ~p7[2];

reg [1:0] cmd = 2'b00;
reg [1:0] addr = 2'b00;

assign p2_oe = w_en_reg & ~prog_n;

always_latch begin
	if(prog_n) begin
		cmd <= p2i[3:2];
		addr <= p2i[1:0];
		w_en_reg <= 1'b0;
		if(p2i[3:2] == 2'b00)
			w_en_reg <= 1'b1;
	end
end

always_ff @(posedge prog_n) begin
	case(cmd)
		2'b00: // read
		begin
			; // Do nothing
		end
		2'b01: // write
		begin
			case (addr)
				2'b00: rx_data[3:0] <= p2i; // p4
				2'b01: rx_data[7:4] <= p2i; // p5
				2'b11: p7 <= p2i; // p7
			endcase
		end
		2'b10: // OR
			if(addr == 2'b11) p7 <= p7 | p2i;
		2'b11: // AND
			if(addr == 2'b11) p7 <= p7 & p2i;
	endcase
end
wire [3:0] p6 = {~tx_ack, 1'b1, 1'b0, ~tx_data_available};

always_comb begin
	case(addr[1:0])
		2'b00: // port 4
			p2o = tx_data[3:0];
		2'b01: // port 5
			p2o = tx_data[7:4];
		2'b10: // port 6
			p2o = p6;
		2'b11: // port 7; never read
			p2o = 4'h0;
	endcase
end
endmodule