`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

module Hovalaag_test;

	// Inputs
	reg clk;
	reg [11:0] IN1;
	reg [11:0] IN2;
	reg [31:0] instr;
	reg rst;

	// Outputs
	wire IN1_adv;
	wire IN2_adv;
	wire [11:0] OUT;
	wire OUT_valid;
	wire OUT_select;
	wire [7:0] PC_out;

	// Instantiate the Unit Under Test (UUT)
	Hovalaag uut (
		.clk(clk), 
		.IN1(IN1), 
		.IN1_adv(IN1_adv), 
		.IN2(IN2), 
		.IN2_adv(IN2_adv), 
		.OUT(OUT), 
		.OUT_valid(OUT_valid), 
		.OUT_select(OUT_select), 
		.instr(instr), 
		.PC_out(PC_out), 
		.rst(rst)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		IN1 = 0;
		IN2 = 0;
		instr = 0;
		rst = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		#5;
		rst = 1;
		#10;
		rst = 0;
		
		//              ALU-A-B-C-DW-F-PCOIXK-----L-----
		#20 instr = 32'b00000011000000100001000010011111;
		#20 instr = 32'b00100011010000000001000000001010;
		#20 instr = 32'b00100111000000000001000000010001;
		#20 instr = 32'b00000000000010000001000000000000;
		#20 instr = 32'b00010000000010000101000000000000;
		#20 instr = 32'b00100000000010000101000000000000;
		#20 instr = 32'b00110000000010000101000000000000;
		#20 instr = 32'b01000000000010000101000000000000;
		#20 instr = 32'b01010000000010000101000000000000;
		#20 instr = 32'b01100000000010000101000000000000;
		#20 instr = 32'b01110000000010000101000000000000;
		#20 instr = 32'b10000000000010000101000000000000;
		#20 instr = 32'b10100000000010000101000000000000;
		#20 instr = 32'b10010000000010000101000000000000;
		#20 instr = 32'b10110000000010000101000000000000;
		#20 instr = 32'b11000000000010000101000000000000;
		#20 instr = 32'b00000000000000001101000000000011;

	end
	
	always
		#10 clk = !clk;
      
endmodule

