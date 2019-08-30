module sync2
#(parameter RESET_VALUE = 1'b1)
(
	input wire clk,
	input wire nrst,
	input wire d,
	output wire q
);

reg x, q_reg;
assign q = q_reg;

always_ff @(posedge clk, negedge nrst) begin
	if(~nrst) begin
		x <= RESET_VALUE;
		q_reg <= RESET_VALUE;
	end else begin
		x <= d;
		q_reg <= x;
	end
end

endmodule
