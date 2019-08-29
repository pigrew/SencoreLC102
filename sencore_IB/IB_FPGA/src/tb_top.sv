`timescale 1ns/10ps
module tb_top;

// OKI minimums; nanoseconds
localparam cmd_setup_min = 50, cmd_hold_min=60;
localparam t_prog_min = 700;
localparam data_setup_min = 200;
localparam data_hold_min = 20;

localparam uart_bittime=8000;

enum bit [1:0] {READ=2'b00, WRITE=2'b01, OP_OR=2'b10, OP_AND=2'b11} busOp;
reg clk=1'b0;

always begin
	#125ns clk = ~clk; // 8 MHz
end

wire [3:0] p2o;
reg prog_n = 1'b1;

wire tx, rts;
reg rx=1'b1, cts=1'b1;

wire LED;
wire p2_buf_oe;
wire p2_buf_dir;

wire [3:0] p2_fpga;
wire [3:0] p2_bus; // bus, on the MCU side

reg [3:0] p2_mcu = 'z; // MCU driver
assign p2_bus = p2_mcu;

tb_levTrans LVTRANS (.oe(p2_buf_oe), .dir(p2_buf_dir), .a(p2_fpga), .b(p2_bus));

pullup PU_B[3:0] (p2_bus);
pullup PU_F[3:0] (p2_fpga);

top TOP(
	.p2(p2_fpga), .*
);

task readport(input bit [1:0] addr, output bit [3:0] result);
	p2_mcu = {READ,addr};
	#(cmd_setup_min*(1ns));
	prog_n = 1'b0;
	#(cmd_hold_min*(1ns));
	p2_mcu = 'z;
	#(t_prog_min*(1ns));
	result = p2_bus;
	prog_n = 1'b1;
	#1us; // extra unneeded delay???
endtask

task writeport(input bit [3:0] cmd, input bit [3:0] data);
	p2_mcu = cmd;
	#(cmd_setup_min*(1ns));
	prog_n = 1'b0;
	#(cmd_hold_min*(1ns));
	p2_mcu = 'z;
	#((t_prog_min-cmd_hold_min +data_setup_min)*(1ns));
	p2_mcu = data;
	#(data_setup_min*(1ns));
	prog_n = 1'b1;
	#(data_hold_min*(1ns));
	p2_mcu = 'z;
	#1us; // extra unneeded delay???
endtask

task uart_tx(input bit [7:0] data);
	integer j;
	while(rts) begin
		#1ns;
	end;
	rx=1'b0; // start bit
	#(uart_bittime*(1ns));
	for(j=0; j<8; j++) begin
		rx = data[j];
		#(uart_bittime*(1ns));
	end
	rx=1'b1; // stop bit
	#(uart_bittime*(1ns));
endtask


initial begin
	#10us
	uart_tx(8'hDE);
	uart_tx(8'hAD);
	uart_tx(8'hBE);
	uart_tx(8'hEF);
end

bit [3:0] scratch;
bit [7:0] data;
integer i;
initial begin
	
	readport(2'd0,scratch); // Set ports to read mode
	readport(2'd1,scratch);
	readport(2'd2,scratch);
	
	/*
	writeport({WRITE,2'd3},4'b1111); // set write mode???
	readport(2'd2,scratch);
	
	
	
	for(i=0; i<3; i++) begin
		writeport({WRITE,2'd0},4'h4); // write data
		writeport({WRITE,2'd1},4'h4);
		writeport({OP_AND,2'd3},4'b1011); // set p7.2 write_available
		
		do begin
			readport(2'd2,scratch);
			$display("p6 = %0b",scratch);
		end while (scratch[3]);
		writeport({OP_OR,2'd3},4'b0100); // set p7.2 write_available
		
	end
	
	*/
	
	// Initialize and set as read mode
	#5us;
	readport(2'd0,scratch); // Set ports to read mode
	readport(2'd1,scratch);
	readport(2'd2,scratch);
	writeport({WRITE,2'd3},4'b1111);
	writeport({WRITE,2'd3},4'b1110); // Read mode
	
	for(i=0; i<8; i++) begin
		// Read a byte (twice)
		do begin
			readport(2'd2,scratch);
			//$display("p6 = %0b",scratch);
		end while (scratch[0]);
			
		readport(2'd0,data[3:0]);
		readport(2'd1,data[7:4]);
		$display("Data = %0x",data);
		
		writeport({OP_AND,2'd3},4'b1101); // set p7.1 read_complete
		do begin
			readport(2'd2,scratch);
			//$display("p6 = %0b",scratch);
		end while (~scratch[0]);
		writeport({OP_OR,2'd3},4'b1111); // restore p7.1 read_complete
	end
	
end

endmodule