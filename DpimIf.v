`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell
//
// Based on DEPP sample logic from Digilent
//
// Allows programming over USB of 256 entry arrays, 
// one of 32-bit instructions and 2 of 12-bit inputs.
module DpimIf(
    input clk,
    input EppAstb_in,
    input EppDstb_in,
    input EppWR,
    output EppWait,
    inout [7:0] EppDB,
	 
	 output program_set,
	 output [7:0] program_addr,
	 output [31:0] program_data,
	 input input1_rdy,
	 input input2_rdy,
	 output input1_set,
	 output input2_set,
	 output [10:0] input_addr,
	 output [11:0] input_data
    );

// Top 4 bits define state, bottom 4 bits set control signals
	localparam [7:0] ST_READY     = 8'b00000000;
	localparam [7:0] ST_ADDR_WR_A = 8'b00010100;
	localparam [7:0] ST_ADDR_WR_B = 8'b00100001;
	localparam [7:0] ST_ADDR_RD_A = 8'b00110010;
	localparam [7:0] ST_ADDR_RD_B = 8'b01000011;
	localparam [7:0] ST_DATA_WR_A = 8'b01011000;
	localparam [7:0] ST_DATA_WR_B = 8'b01100001;
	localparam [7:0] ST_DATA_RD_A = 8'b01110010;
	localparam [7:0] ST_DATA_RD_B = 8'b10000011;

	// Buffer EPP strobes
	reg EppAstb;
	reg EppDstb;
	always @(posedge clk) begin
		EppAstb <= EppAstb_in;
		EppDstb <= EppDstb_in;
	end

	reg [7:0] state = ST_READY;
	reg [7:0] nextState = ST_READY;

	wire EppDir;
	wire EppAddrWr;
	wire EppDataWr;
	wire [7:0] busEppIn;
	wire [7:0] busEppOut;
	
	assign EppWait   = state[0];
	assign EppDir    = state[1];
	assign EppAddrWr = state[2];
	assign EppDataWr = state[3];
   
	assign busEppIn = EppDB;
	assign EppDB = (EppWR == 1'b1 && EppDir == 1'b1) ? busEppOut : 8'bZZZZZZZZ;
			
	reg [7:0] regAddr = 8'h00;
	wire [7:0] dataOut;
	
	// Register layout:
	// 0: Control register:
	//     0x01: Set program instruction.
	//     0x02: Set input 1 data.
	//     0x03: Set input 2 data.
   //		 0x81: Commit program instruction.
   //		 0x82: Commit input 1 data.
   //		 0x83: Commit input 2 data.
	//     0xc1-c3: Set remaining addresses to current contents of data registers.
	// 1: Address register
	// 2-3/2-5: Input / program data bytes (little endian, so reg 2 contains bit 31-24, etc)
	// 6: High address register (for input data only)
	// 7: Input required - bitfield: 1, input 1; 2 input 2
	//
	// Examples:
	// To write one 32-bit word of program:
	// First set register 0 to 1.
	// Then set program instruction address and data in registers 1-5.
	// Set register 0 to 0x81 to commit that line of program
	//
	// To clear the input 1 data
	// Set register 0 to 2
	// Set address and data registers to 0
	// Set register 0 to 0xc2
	reg [7:0] ctrlReg = 8'h00;
	reg [10:0] programAddr = 11'h000;
	reg [31:0] programData = 8'h00;
	
	assign busEppOut = (EppAstb == 1'b0) ? regAddr : dataOut;
	assign dataOut = (regAddr == 8'h00) ? ctrlReg :
	                 (regAddr == 8'h01) ? programAddr[7:0] :
	                 (regAddr == 8'h02) ? programData[31:24] :
	                 (regAddr == 8'h03) ? programData[23:16] :
	                 (regAddr == 8'h04) ? programData[15:8] :
	                 (regAddr == 8'h05) ? programData[7:0] :
	                 (regAddr == 8'h06) ? {5'b00000,programAddr[10:8]} : 
						  (regAddr == 8'h07) ? {6'b000000,input2_rdy,input1_rdy} :
						  8'h00;

	assign program_set = ((ctrlReg & 8'h8F) == 8'h81);
	assign input1_set = ((ctrlReg & 8'h8F) == 8'h82);
	assign input2_set = ((ctrlReg & 8'h8F) == 8'h83);
	assign program_addr = programAddr[7:0];
	assign program_data = programData;
	assign input_addr = programAddr;
	assign input_data = programData[27:16];
	
	always @(posedge clk)
		state <= nextState;
	
	always @(*) begin
		case (state)
		ST_READY: begin
			if (EppAstb == 1'b0) begin
				if (EppWR == 1'b0)
					nextState = ST_ADDR_WR_A;
				else
					nextState = ST_ADDR_RD_A;
			end
			else if (EppDstb == 1'b0) begin
				if (EppWR == 1'b0)
					nextState = ST_DATA_WR_A;
				else
					nextState = ST_DATA_RD_A;
			end
			else
				nextState = ST_READY;
		end
		ST_ADDR_WR_A: nextState = ST_ADDR_WR_B;
		ST_ADDR_WR_B: begin
			if (EppAstb == 1'b0)
				nextState = ST_ADDR_WR_B;
			else
				nextState = ST_READY;
		end
		ST_ADDR_RD_A: nextState = ST_ADDR_RD_B;
		ST_ADDR_RD_B: begin
			if (EppAstb == 1'b0)
				nextState = ST_ADDR_RD_B;
			else
				nextState = ST_READY;			
		end
		ST_DATA_WR_A: nextState = ST_DATA_WR_B;
		ST_DATA_WR_B: begin
			if (EppDstb == 1'b0 || ctrlReg[6] == 1'b1)
				nextState = ST_DATA_WR_B;
			else
				nextState = ST_READY;
		end
		ST_DATA_RD_A: nextState = ST_DATA_RD_B;
		ST_DATA_RD_B: begin
			if (EppDstb == 1'b0)
				nextState = ST_DATA_RD_B;
			else
				nextState = ST_READY;
		end
		default: nextState = ST_READY;
		endcase
	end
	
	always @(posedge clk) begin
		if (EppAddrWr)
			regAddr <= busEppIn;
		else if (EppDataWr)
			case (regAddr)
			8'h00: ctrlReg <= busEppIn;
			8'h01: programAddr[7:0] <= busEppIn;
			8'h02: programData[31:24] <= busEppIn;
			8'h03: programData[23:16] <= busEppIn;
			8'h04: programData[15:8] <= busEppIn;
			8'h05: programData[7:0] <= busEppIn;
			8'h06: programAddr[10:8] <= busEppIn[2:0];
			endcase
		else if (ctrlReg[6]) begin
			if ((ctrlReg[1:0] == 2'b01 && programAddr[7:0] == 8'hFF) || (programAddr == 11'h7FF))
				ctrlReg[6] <= 1'b0;
			else
				programAddr <= programAddr + 1'b1;
		end
	end

endmodule
