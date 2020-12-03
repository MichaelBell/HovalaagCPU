`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Definition of input data.
module Input1(
    input clk,
	 input rst,
    input adv1,
    output reg [11:0] data1,
	 
	 input in1_write,
	 input [12:0] addr_in,
	 input [11:0] data_in
    );

	reg [12:0] addr1 = 13'h0000;
	
	reg [11:0] input1_array [0:8191];
	
	always @(posedge clk) begin
		if (rst) begin
			addr1 <= 13'h0000;
		end
		else begin
			data1 <= input1_array[addr1];

			if (adv1) addr1 <= addr1 + 1'b1;
		end
	end

	always @(posedge clk) begin
		if (in1_write)
			input1_array[addr_in] <= data_in;
	end
endmodule
