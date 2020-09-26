`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Lookup the segments that should be active for each hex digit on a
// seven segment display.  Note 0 corresponds to a lit segment.
module SevenSegLookup(
    input [3:0] num,
    output reg [7:0] seg
    );

	always @* begin
		case (num)
		4'h0 : seg <= 8'b11000000;
		4'h1 : seg <= 8'b11111001;
		4'h2 : seg <= 8'b10100100;
		4'h3 : seg <= 8'b10110000;
		4'h4 : seg <= 8'b10011001;
		4'h5 : seg <= 8'b10010010;
		4'h6 : seg <= 8'b10000010;
		4'h7 : seg <= 8'b11111000;
		4'h8 : seg <= 8'b10000000;
		4'h9 : seg <= 8'b10010000;
		4'hA : seg <= 8'b10001000;
		4'hB : seg <= 8'b10000011;
		4'hC : seg <= 8'b11000110;
		4'hD : seg <= 8'b10100001;
		4'hE : seg <= 8'b10000110;
		4'hF : seg <= 8'b10001110;
		endcase
	end

endmodule
