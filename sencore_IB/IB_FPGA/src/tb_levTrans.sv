module tb_levTrans(
input wire oe,
input wire dir,

inout [3:0] a,
inout [3:0] b
);

assign a = (~oe & ~dir) ? b : 'z;
assign b = (~oe &  dir) ? a : 'z;

endmodule
