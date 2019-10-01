`default_nettype none

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
	
	input wire talk,
	output wire talk_ack,
	
	// data Meter->IB->UART
	output reg [7:0] rx_data,
	input wire tx_ack, // ~p6.2
	output wire rx_data_available// p7.2
);
// Command/addr is latched when n_prog is HIGH. It's generally OK if bad data is latched given
// that no action is taken at the first rising edge of nPROG after reset is removed.
// So, lets synchronize the (local) reset signal to nPROG (which serves as the clock).
// Reset should be removed soon after the rising edge of nPROG.

// The exception is w_en_reg, which does need to be reset so that we don't write at the wrong
// time during a reset

// However, this means that we need two dummy reads at startup in order to leave reset.

// This module encodes the combined behavior of the Sencore IB and the expander, but just enough
// that it works, but doesn't fully implement either independantly.

// This module also delays the enable by about 375ns to avoid some bus contention.
// The 8243 has an access time of <650ns, but the MCU only requires an access time of <700ns (@11MHz).
// The nPROG pulse width may be as short as 700ns.

// To do this, one can AND the we signal with a delayed nprog (passed through a 2 gate synchronizer,
// which delays up to 4 (or so) clock cycles).

wire nrst_local;
sync2 #(.RESET_VALUE(1'b0)) nPROG_RST_SYNC2 (.clk(prog_n), .nrst(nrst), .d(1'b1), .q(nrst_local));

wire p2_oe_guard_n;
sync2 #(.RESET_VALUE(1'b1)) nPROG_DELAY_SYNC (.clk(clk), .nrst(~prog_n & nrst), .d(prog_n), .q(p2_oe_guard_n));

reg w_en_reg;
wire write_mode;

reg [3:0] p7;

assign tx_data_ack_n = p7[1];
assign rx_data_available = ~p7[2];
assign write_mode = p7[0];

reg [1:0] cmd;
reg [1:0] addr;

assign p2_oe = w_en_reg & ~prog_n & ~p2_oe_guard_n;

assign talk_ack = ~p7[2];

// Reset is required to prevent spurious write_enables on the output port.
// I had coded this as an "if (~nrst) {...} else if(prog_n) {...}" but synopsys complained it wasn't a latch.
always_latch begin
	if(~nrst_local | prog_n) begin
		if(~nrst_local) begin
			w_en_reg <= 1'b0;
			cmd <= 2'b01; // read
			addr <= 2'b00;
		end else begin
			cmd <= p2i[3:2];
			addr <= p2i[1:0];
			w_en_reg <= 1'b0;
			if(p2i[3:2] == 2'b00)
				w_en_reg <= 1'b1;
		end
	end
end

always_ff @(posedge prog_n or negedge nrst_local) begin
	if(~nrst_local) begin
		p7 <= 4'hF;
		rx_data <= 'x;
	end else begin
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
end

wire [3:0] p6 = {~tx_ack, ~(write_mode & talk), 1'b0, ~tx_data_available};
// 0 0 => 4
// 0 1 => 5
// 1 0 => c
// 1 1 => d

// d is 1101
// e is 1110
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