module clkdiv(
	input wire clk,
	input wire nrst,
	output wire clk5,
	output wire clk10
);

localparam DIV_WIDTH = 10;
// CLK10 is 7.8125 kHz
// CLK5 is faster. (250 kHz?)

reg [DIV_WIDTH-1:0] t;
assign clk5 = t[4:0] == '0;
assign clk10 = t[9:0] == '0;

always_ff @(posedge clk or negedge nrst) begin
	if(~nrst) begin
		t <= '1;
	end else begin
		t <= t - {{(DIV_WIDTH-1){1'b0}},1'b1};
	end
end


endmodule