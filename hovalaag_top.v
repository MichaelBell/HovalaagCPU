`timescale 1ns / 1ps
// Copyright (C) 2020 Michael Bell

//  Hovalaag CPU harness for Digilent Basys 2 board
//
// 7 segment display displays last value written to OUT1 or OUT2,
//  depending on position of SW0 (down = OUT1, up = OUT2)
//
// The LEDs indicate address of next instruction to be executed
//
// If SW1 is down pressing BTN3 clocks the CPU once
// If SW1 is up, the CPU clocks at about 1.5Hz (SW2 down) or 12Hz (SW2 up)
// Pressing BTN0 resets the CPU.
module hovalaag_top(
    input clk,
	 output [7:0] Led,
	 output [7:0] seg,
	 output [3:0] an,
	 input [7:0] sw,
	 input [3:0] btn
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
	
	// Clock control
	reg [23:0] counter = 24'b000000000000000000000000;
	reg slowclk = 1'b0;
	reg step_btn = 1'b0;
	
	always @(posedge clk) begin
		if (sw[1]) begin
			counter = counter + 1'b1;
			if (counter == 24'b000000000000000000000000) begin
				slowclk = !slowclk;
				if (sw[2]) counter = 24'b111000000000000000000000;
			end
		end
		else begin
			if (!step_btn && btn[3])
				slowclk = !slowclk;
			if (slowclk || !btn[3])
				step_btn = btn[3];
		end
	end
	
	// Instantiate CPU and program block ROM
	Hovalaag cpu(slowclk, IN1, IN1_adv, IN2, IN2_adv, OUT, OUT_valid, OUT_select, instr, addr, reset);
	Program prog(clk, addr, instr);

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
			if (OUT_select == 1'b0) OUT1 <= OUT;
			else OUT2 <= OUT;
		end
	end
	
	// Display selected output register
	assign displayOUT = sw[0] ? OUT2 : OUT1;
	SevenSeg display(clk, displayOUT, seg, an);

	// Display next PC
	assign Led = addr[7:0];

endmodule
