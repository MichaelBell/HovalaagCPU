// Copyright (C) 2020 Michael Bell

// Hovalaag ALU function
function [12:0] HovalaagALU(
    input [3:0] alu_op,
    input [11:0] A,
    input [11:0] B,
    input [11:0] C,
    input F
    );

		case (alu_op)
			4'b0000: HovalaagALU = 13'b0000000000000;
			4'b0001: HovalaagALU = -A;
			4'b0010: HovalaagALU = B;
			4'b0011: HovalaagALU = C;
			4'b0100: HovalaagALU = {A[0],1'b0,A[11:1]};
			4'b0101: HovalaagALU = A+B;
			4'b0110: HovalaagALU = B-A;			
			4'b0111: HovalaagALU = A+B+F;
			4'b1000: HovalaagALU = B-A-F;
			4'b1001: HovalaagALU = A|B;
			4'b1010: HovalaagALU = A&B;
			4'b1011: HovalaagALU = A^B;
			4'b1100: HovalaagALU = ~A;
			default: HovalaagALU = A;
		endcase

endfunction
