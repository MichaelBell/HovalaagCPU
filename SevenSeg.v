`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Displays a 12 bit input in hex on the seven segment display
module SevenSeg(
    input clk,
    input [11:0] data,
	 output [7:0] seg,
	 output [3:0] an
    );
	
	wire [3:0] num;
	wire [7:0] lookupResult;
	
	SevenSegLookup lookup(num, lookupResult);
	 
	reg [15:0] counter = 16'h0000;
	reg [7:0] segReg;
	reg [3:0] anReg;
	reg [3:0] numReg;
	reg [1:0] digitSelect = 2'b00;
	
	assign seg = segReg;
	assign an = anReg;
	assign num = numReg;

	always @(posedge clk) begin
		// Digit select - the display works by cycling through lighting each of the 4
		// seven segment displays in turn.
		if(counter == 16'b1111111111111111) begin
			digitSelect = digitSelect + 1'b1;
			counter <= 16'h0000;
			
			case (digitSelect)
			2'b00: numReg <= 4'h0;
			2'b01: numReg <= data[11:8];
			2'b10: numReg <= data[7:4];
			2'b11: numReg <= data[3:0];
			endcase
		end
		else begin
			counter <= counter + 1'b1;
			
			case (digitSelect)
			2'b00: begin
				anReg <= 4'b0111;
				segReg <= 8'hff;
			end
			2'b01: begin
				anReg <= 4'b1011;
				segReg <= lookupResult;
			end
			2'b10: begin
				anReg <= 4'b1101;
				segReg <= lookupResult;
			end
			2'b11: begin
				anReg <= 4'b1110;
				segReg <= lookupResult;
			end
			endcase
		end
	end

endmodule
