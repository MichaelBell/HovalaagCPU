`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Definition of input data.
module Input(
    input clk,
	 input rst,
    input adv1,
    input adv2,
    output reg [11:0] data1,
    output reg [11:0] data2,
	 
	 input in1_write,
	 input in2_write,
	 input [7:0] addr_in,
	 input [11:0] data_in
    );

	reg [7:0] addr1 = 8'h00;
	reg [7:0] addr2 = 8'h00;
	
	reg [11:0] input1_array [255:0];
	reg [11:0] input2_array [255:0];
	
	always @(posedge clk) begin
		if (rst) begin
			addr1 <= 8'h00;
			addr2 <= 8'h00;
		end
		else begin
			data1 <= input1_array[addr1];
			data2 <= input2_array[addr2];

			if (adv1) addr1 <= addr1 + 1'b1;
			if (adv2) addr2 <= addr2 + 1'b1;
		end
	end

	always @(posedge clk) begin
		if (in1_write)
			input1_array[addr_in] <= data_in;
		if (in2_write)
			input2_array[addr_in] <= data_in;
	end
endmodule
