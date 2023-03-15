// Copyright (C) 2020 Michael Bell

// Hovalaag ALU function
function [12:0] HovalaagALU(
    input [3:0] alu_op,
    input [12:0] A,
    input [12:0] B,
    input [12:0] C,
	input [12:0] op_14_source,
	input [12:0] op_15_source,
    input F
    );

		case (alu_op)
			4'b0000: HovalaagALU = 13'b0000000000000;
			4'b0001: HovalaagALU = -A;
			4'b0010: HovalaagALU = B;
			4'b0011: HovalaagALU = C;
			4'b0100: HovalaagALU = {A[0],A[12:1]};
			4'b0101: HovalaagALU = A+B;
			4'b0110: HovalaagALU = B-A;			
			4'b0111: HovalaagALU = A+B+F;
			4'b1000: HovalaagALU = B-A-F;
			4'b1001: HovalaagALU = A|B;
			4'b1010: HovalaagALU = A&B;
			4'b1011: HovalaagALU = A^B;
			4'b1100: HovalaagALU = ~A;
			4'b1101: HovalaagALU = A;
			4'b1110: HovalaagALU = op_14_source;
			4'b1111: HovalaagALU = op_15_source;
		endcase

endfunction
