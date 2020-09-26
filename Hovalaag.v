`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

// Hovalaag CPU implementation, see http://silverspaceship.com/hovalaag/docs.html
// for full documentation
//
// The CPU has no pipelining at all, the instruction at address PC_out
// must be ready on the instr input for the next clock.
//
// Inputs should be presented on IN1 and IN2, if they are consumed then IN1/IN2_adv is
// set high and the next input should be provided.
//
// Outputs are sent on OUT when OUT_valid is high.  OUT_select indicates whether the output is
// for OUT1 (OUT_select low) or OUT2 (OUT_select high).
//
// If rst is high, then all registers are reset to zero and no instructions are executed.
module Hovalaag(
	 input clk,

    input [11:0] IN1,
	 output IN1_adv,
    input [11:0] IN2,
	 output IN2_adv,
	 
    output reg [11:0] OUT,
	 output reg OUT_valid,
	 output reg OUT_select,
	 
	 input [31:0] instr,
	 output [7:0] PC_out,
	 
	 input rst
    );

	// Instruction parts
	wire [3:0] alu_op;
	wire [1:0] A_op;
	wire [1:0] B_op;
	wire [1:0] C_op;
	wire D_op;
	wire [1:0] W_op;
	wire [1:0] F_op;
	wire [1:0] PC_op;
	wire IO_select;
	wire [11:0] K;
	wire [7:0] L;
	
	// Instruction assignment
	assign alu_op = instr[31:28];
	assign A_op = instr[27:26];
	assign B_op = instr[25:24];
	assign C_op = instr[23:22];
	assign D_op = instr[21];
	assign W_op = instr[20:19];
	assign F_op = instr[18:17];
	assign PC_op = instr[16:15];
	assign IO_select = instr[13];
	assign K = (instr[12]) ? instr[11:0] : { {6{instr[11]}}, instr[11:6] };
	assign L = (instr[12]) ? instr[7:0] : {2'b00,instr[5:0]};
	always @(posedge clk) begin
		OUT_valid <= instr[14];
		OUT_select <= IO_select;
	end
	
	// Select and consume input
	wire [11:0] IN;
	wire IN_used;
	assign IN = (IO_select) ? IN2 : IN1;
	assign IN_used = (A_op == 2'b11);
	assign IN1_adv = (IO_select == 1'b0) & IN_used;
	assign IN2_adv = (IO_select == 1'b1) & IN_used;

	// Registers
	reg [11:0] A = 12'h000;
	reg [11:0] B = 12'h000;
	reg [11:0] C = 12'h000;
	reg [11:0] D = 12'h000;
	reg [11:0] W = 12'h000;
	reg F = 1'b0;
	wire [11:0] M;
	wire newF;
	reg [7:0] PC = 8'h00;
	
	// Outputs
	assign PC_out = PC;
	
	// ALU
`include "HovalaagALU.v"
	assign {newF,M} = HovalaagALU(alu_op, A, B, C, F);
	
	always @(posedge clk) begin
		if (rst == 1'b1) begin
			A <= 12'h000;
			B <= 12'h000;
			D <= 12'h000;
			W <= 12'h000;
			F = 1'b0;
			C = 12'h000;
			PC = 8'h00;
		end
		else begin
			// A unit
			case (A_op)
			2'b00: A <= A;
			2'b01: A <= M;
			2'b10: A <= D;
			2'b11: A <= IN;
			endcase
			
			// B unit
			case (B_op)
			2'b00: B <= B;
			2'b01: B <= M;
			2'b10: B <= A;
			2'b11: B <= K;
			endcase
			
			// D unit
			if (D_op) D <= A; else D <= D;
			
			// Output
			OUT <= W;
			
			// W unit
			case (W_op)
			2'b00: W <= W;
			2'b01: W <= M;
			2'b10: W <= A;
			2'b11: W <= K;
			endcase
			
			// F unit
			case (F_op)
			2'b00: F = F;
			2'b01: F = ({newF,M} == 13'b0000000000000) ? 1'b1 : 1'b0;
			2'b10: F = newF;
			2'b11: F = !newF;
			endcase			
			
			// C unit
			case (C_op)
			2'b00: C = C;
			2'b01: C = M;
			default: C = C - 1'b1;
			endcase
			
			if (C_op == 2'b11 && C != 12'h000) begin
			   // DECNZ overrides normal PC operation.
				PC = L;
			end
			else begin
				// PC unit
				case (PC_op)
				2'b00: PC = PC + 1'b1;
				2'b01: PC = L;
				2'b10: PC = (F) ? L : PC + 1'b1;
				2'b11: PC = (F) ? PC + 1'b1 : L;
				endcase	
			end
		end
	end

endmodule
