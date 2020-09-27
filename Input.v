`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Definition of input data.
module Input(
    input clk,
	 input rst,
    input adv1,
    input adv2,
    output reg [11:0] data1,
    output reg [11:0] data2
    );

	reg [7:0] addr1 = 8'h00;
	reg [7:0] addr2 = 8'h00;
	
	always @(posedge clk) begin
		if (rst) begin
			addr1 <= 8'h00;
			addr2 <= 8'h00;
		end
		else begin
			case (addr1)
			8'h00:  data1 = 12'h005;
			8'h01:  data1 = 12'h001;
			8'h02:  data1 = 12'h005;
			8'h03:  data1 = 12'h007;
			8'h04:  data1 = 12'h001;
			8'h05:  data1 = 12'h002;
			8'h06:  data1 = 12'h009;
			8'h07:  data1 = 12'h008;
			8'h08:  data1 = 12'h001;
			8'h09:  data1 = 12'h002;
			8'h0a:  data1 = 12'h004;
			8'h0b:  data1 = 12'h003;
			8'h0c:  data1 = 12'h006;
			8'h0d:  data1 = 12'h001;
			8'h0e:  data1 = 12'h005;
			8'h0f:  data1 = 12'h005;

			default: data1 = 12'h000;
			endcase
			
			case(addr2)
			8'h00:  data2 = 3;
			8'h01:  data2 = -3;
			8'h02:  data2 = -3;
			8'h03:  data2 = 4;
			8'h04:  data2 = -4;
			8'h05:  data2 = 1;
			8'h06:  data2 = -3;
			8'h07:  data2 = -4;
			8'h08:  data2 = 3;
			default: data2 = 12'h000;
			endcase

			if (adv1) addr1 <= addr1 + 1'b1;
			if (adv2) addr2 <= addr2 + 1'b1;
		end
	end
endmodule
