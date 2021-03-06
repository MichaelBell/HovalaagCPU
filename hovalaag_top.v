`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

//  Hovalaag CPU harness for Digilent Basys 2 board
//
// 7 segment display normally displays last value written to OUT1 or OUT2,
//  depending on position of SW0 (down = OUT1, up = OUT2)
// Pressing BTN1 displays the waiting input (IN1 or IN2) instead of the last output.
//
// If SW5 is up the Hovalaag registers are instead displayed for debugging
// SW6 and 7 control which register is displayed:
// SW6 down, SW7 down: A
// SW6 up,   SW7 down: B
// SW6 down, SW7 up:   C
// SW6 up,   SW7 up:   D
//
// The LEDs indicate address of next instruction to be executed
//
// If SW1 is down pressing BTN3 clocks the CPU once
// If SW1 is up, the CPU clocks at about 12.5MHz (if SW3 up), or 1.5Hz (SW2 down) or 12Hz (SW2 up)
// If SW4 is up, the CPU pauses on each write to OUT1, pressing BTN2 continues.
// Pressing BTN0 resets the CPU.
module hovalaag_top(
    input clk,
	 output [7:0] Led,
	 output [7:0] seg,
	 output [3:0] an,
	 input [7:0] sw,
	 input [3:0] btn,
	 
	 input EppAstb,
    input EppDstb,
    input EppWR,
    output EppWait,
    inout [7:0] EppDB
    );

	// Connections to Hovalaag CPU
	wire [11:0] IN1;
	wire [11:0] IN2;
	wire [11:0] OUT;
	wire IN1_adv;
	wire IN2_adv;
	wire OUT_valid;
	wire OUT_select;
  
	wire [31:0] instr;
	wire [7:0] addr;
	wire reset = btn[0];

	wire [11:0] A;
	wire [11:0] B;
	wire [11:0] C;
	wire [11:0] D;
	
	// Programming
	wire program_write;
	wire [7:0] program_addr;
	wire [31:0] program_data;
	wire in1_set;
	wire in2_set;
	wire in1_rdy;
	wire in2_rdy;
	wire [10:0] input_addr;
	wire [11:0] input_data;
	
	// Clock control
	reg [23:0] counter = 24'b000000000000000000000000;
	reg slow_clk = 1'b0;
	reg step_btn = 1'b0;
	reg pause = 1'b0;
	
	// Input advance control (only advance once)
	reg do_hoval_IN = 1'b0;
	reg do_hoval_OUT;
	
	always @(posedge clk) begin
		do_hoval_OUT <= do_hoval_IN;
		
		if (pause || in1_rdy || in2_rdy) begin
			// Do nothing while paused
			do_hoval_IN <= 1'b0;
		end 
		else if (sw[1]) begin
			counter = counter + 1'b1;
			if (counter == 24'b000000000000000000000000) begin
				slow_clk <= !slow_clk;
				do_hoval_IN <= !slow_clk;
				if (sw[3]) counter = 24'b111111111111111111111100;
				else if (sw[2]) counter = 24'b111000000000000000000000;
			end
			else
			  do_hoval_IN <= 1'b0;
		end
		else begin
			if (!step_btn && btn[3]) begin
				slow_clk <= 1'b1;
				do_hoval_IN <= 1'b1;
			end
			else begin
			   slow_clk <= 1'b0;
				do_hoval_IN <= 1'b0;
			end
			step_btn <= btn[3];
		end
	end
	
	// Instantiate CPU and program block RAM
	Hovalaag cpu(slow_clk, IN1, IN1_adv, IN2, IN2_adv, OUT, OUT_valid, OUT_select, instr, addr, A, B, C, D, reset);
	DpimIf dpim(clk, EppAstb, EppDstb, EppWR, EppWait, EppDB, program_write, program_addr, program_data, in1_rdy, in2_rdy, in1_set, in2_set, input_addr, input_data);
	Program prog(clk, addr, instr, program_write, program_addr, program_data);
	
	// Two input data banks version
	//Input inp(clk, reset, IN1_adv & do_hoval_IN, IN2_adv & do_hoval_IN, IN1, IN2, in1_set, in2_set, input_addr[7:0], input_data);
	
	// Loopback OUT2 to IN2 version
	Input1 inp(clk, reset, IN1_adv & do_hoval_IN, IN1, in1_rdy, in1_set, input_addr, input_data);
	assign in2_rdy = 1'b0;
	Fifo fifo(clk, reset, OUT_select & OUT_valid & do_hoval_OUT, OUT, IN2, IN2_adv & do_hoval_IN);

	// Handle output, currently just saved in a register.
	reg [11:0] OUT1 = 12'h000;
	reg [11:0] OUT2 = 12'h000;
	wire [11:0] displayOUT;

	always @(posedge clk) begin
		if (reset) begin
			OUT1 <= 12'h000;
			OUT2 <= 12'h000;
		end
		else if (OUT_valid) begin
			if (OUT_select == 1'b0) begin
			   OUT1 <= OUT;
				if (sw[4]) pause <= 1'b1;
			end
			else OUT2 <= OUT;
		end
		if (btn[2]) pause <= 1'b0;
	end
	
	// Display selected output register
	assign displayOUT = sw[5] ? ((!sw[7] && !sw[6]) ? A : 
	                             (!sw[7] && sw[6]) ? B : 
										  (sw[7] && !sw[6]) ? C : D) : 
	                     program_write ? program_data[11:0] : (sw[0] ? (btn[1] ? IN2 : OUT2) : (btn[1] ? IN1 : OUT1));
	SevenSeg display(clk, displayOUT, OUT_valid & (OUT_select == sw[0]), seg, an);

	// Display next PC
	assign Led = program_write ? program_addr : addr;

endmodule
