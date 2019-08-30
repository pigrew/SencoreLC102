module ledLatch(
	input wire clk,
	input wire d, // d should be synchronous to the clock. trigger is active high.
	output wire q // q is active high, so will need to be inverted to drive the LED open-drain.
);

localparam TIMER_BITS = 15;

reg q_reg, q_reg_next;
assign q = q_reg;

reg [TIMER_BITS-1:0] timer = '0;
reg [TIMER_BITS-1:0] timer_next;

always_ff @(posedge clk) begin
	timer <= timer_next;
	q_reg <= q_reg_next;
end

always_comb begin
	if(d) begin
		timer_next = '1;
	end else if(timer == 0) begin
		timer_next = '0;
	end else begin
		timer_next = timer - {{(TIMER_BITS-1){1'b0}},1'b1};
	end
	q_reg_next = (timer != 0);
end

endmodule