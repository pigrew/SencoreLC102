module sync2(
	input wire clk,
	input wire d,
	output reg q
);

reg x;
always_ff @(posedge clk) begin
	x <= d;
	q <= x;
end

endmodule