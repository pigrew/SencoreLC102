module uart_rx(
	input clk,
	input nrst,
	input wire rx,
	output reg rts,
	
	output reg [7:0] data,
	output wire data_valid,
	input wire data_ack_n
);
localparam period = 31;

typedef enum logic[2:0] {INIT, IDLE, START, DATA,STOP, WAIT, WAIT2} state_t;

state_t state, state_next;

reg rts_next;

reg data_valid_r, data_valid_next;
assign data_valid = data_valid_r;

reg [4:0] clkCount, clkCount_next;

reg [4:0] bitCount;reg [4:0] bitCount_next;

reg [7:0] data_next;

always_ff @(posedge clk or negedge nrst) begin
	if(~nrst) begin
		state <= INIT;
		rts <= 1'b0;
		clkCount <= period;
		bitCount <= 5'd8;
		data <= 'x;
		data_valid_r <= 1'b0;
	end else begin
		state <= state_next;
		rts <= rts_next;
		clkCount <= clkCount_next;
		bitCount <= bitCount_next;
		data <= data_next;
		data_valid_r <= data_valid_next;
	end
end

always_comb begin
	rts_next = 1'b1; // not ready
	state_next = state;
	clkCount_next = clkCount - 1;
	bitCount_next = bitCount;
	data_next = data;
	data_valid_next = 1'b0;
	case(state)
	INIT: begin // delay at start to wait for idle line
		if(~rx) begin
			clkCount_next = period;
			bitCount_next = 8;
		end else begin
			if(clkCount == 0) begin
				bitCount_next = bitCount -1;
				if(bitCount == 0) begin
					state_next = IDLE;
				end
			end
		end
	end
	IDLE: begin
		rts_next = 1'b0; // ready
		if(~rx) begin
			clkCount_next = period/2;
			state_next = START;
		end
	end
	START: begin
		rts_next = 1'b0; // ready
		if(clkCount == 0) begin
			bitCount_next = 8;
			clkCount_next = period;
			if(rx) begin
				state_next = IDLE; // Weird, lets abort
			end else begin
				state_next = DATA;
			end
		end
	end
	DATA: begin
		if(clkCount == 0) begin
			bitCount_next = bitCount - 1;
			if(bitCount == 0) begin
				state_next = STOP;
			end else begin
				data_next = {rx,data[7:1]};
				clkCount_next = period;
			end
		end
	end
	STOP: begin
		if(clkCount == 0) begin
			if(~rx) begin // wrong stop bit
				state_next = INIT;
			end else begin
				state_next = WAIT;
				data_valid_next = 1'b1;
			end
		end

	end
	WAIT: begin
		data_valid_next = 1'b1;
		if(~data_ack_n) begin
			state_next = WAIT2;
		end
	end
	WAIT2: begin
		if(data_ack_n) begin
			state_next = IDLE;
		end
	end
	endcase
end

endmodule
