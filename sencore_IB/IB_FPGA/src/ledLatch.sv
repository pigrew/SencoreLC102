module ledLatch(
	input wire clk,
	input wire clk10,
	input wire nrst,
	input wire d, // d should be synchronous to the clock. trigger is active high.
	output reg q // q is active high, so will need to be inverted to drive the LED open-drain.
);

localparam TIMER_BITS = 5;

reg q_next;

reg [TIMER_BITS-1:0] timer;
reg [TIMER_BITS-1:0] timer_next;

always_ff @(posedge clk or negedge nrst) begin
	if(~nrst) begin
		timer <= '0;
		q <= '1;
	end else begin
		timer <= timer_next;
		q <= q_next;
	end
end

always_comb begin
	if(d) begin
		timer_next = '1;
	end else if(timer == 0) begin
		timer_next = '0;
	end else begin
		if(clk10) begin
			timer_next = timer - {{(TIMER_BITS-1){1'b0}},1'b1};
		end else begin
			timer_next = timer;
		end
	end
	q_next = (timer != 0);
end

endmodule