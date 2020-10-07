`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

module Program(
    input clk,
    input [7:0] addr,
    output reg [31:0] data,
	 input write,
	 input [7:0] addr_wr,
	 input [31:0] data_in
    );

	reg [31:0] program_array [0:255];

	 always @(posedge clk)
    begin
        if (write) begin
            program_array[addr_wr] <= data_in;
        end
    end	

	 always @(posedge clk)
    begin
        data <= program_array[addr];
    end	

endmodule
