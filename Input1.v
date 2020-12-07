`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Definition of input data.
module Input1(
    input clk,
	 input rst,
    input adv1,
    output reg [11:0] data1,
	 
	 output in1_rdy,
	 input in1_write,
	 input [10:0] addr_in,
	 input [11:0] data_in
    );

   reg in1_reqd = 1'b0;
	assign in1_rdy = in1_reqd;
	reg [10:0] addr1 = 0;
	reg [11:0] input1_array [0:2047];
	
	always @(posedge clk) begin
		if (rst) begin
			addr1 <= 0;
			in1_reqd <= 1'b0;
		end
		else begin
			data1 <= input1_array[addr1];

			if (in1_write && addr_in == 11'h7ff && addr1 == 0)
				in1_reqd <= 1'b0;
			else if (adv1 && addr1 == 11'h7ff) 
			   in1_reqd <= 1'b1;

			if (adv1) begin
			   addr1 <= addr1 + 1'b1;
			end

			if (in1_write) begin
				input1_array[addr_in] <= data_in;
			end
		end
	end
endmodule
