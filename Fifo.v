`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:27:08 12/01/2020 
// Design Name: 
// Module Name:    Fifo 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Fifo(
    input clk,
	 input rst,
    input data_write,
    input [11:0] data_in,
    output reg [11:0] data_out,
    input data_adv
    );

	reg [12:0] in_addr = 0;
	reg [12:0] out_addr = 0;
	
	reg [11:0] fifo_array [0:8191];
	
	always @(posedge clk) begin
		if (rst) begin
			in_addr <= 0;
			out_addr <= 0;
		end
		else begin
			if (data_write) begin
				fifo_array[in_addr] <= data_in;
				in_addr <= in_addr + 1'b1;
			end

		   if (in_addr == out_addr) 
			   data_out <= 12'h000;
			else begin
			   data_out <= fifo_array[out_addr];
			   if (data_adv) out_addr <= out_addr + 1'b1;
			end
		end
	end

endmodule
