module sync2
#(parameter RESET_VALUE = 1'b1)
(
	input wire clk,
	input wire nrst,
	input wire d,
	output reg q
);

reg x;

always_ff @(posedge clk, negedge nrst) begin
	if(~nrst) begin
		x <= RESET_VALUE;
		q <= RESET_VALUE;
	end else begin
		x <= d;
		q <= x;
	end
end

endmodule
