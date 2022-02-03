`timescale 1 ps/1 ps
`define abs(a)((a) >= 0 ? (a) : (-a))

module SB_PLL40_CORE (
	                    input       REFERENCECLK,
	                    output      PLLOUTCORE,
	                    output      PLLOUTGLOBAL,
	                    input       EXTFEEDBACK,
	                    input [7:0] DYNAMICDELAY,
	                    output      LOCK,
	                    input       BYPASS,
	                    input       RESETB,
	                    input       LATCHINPUTVALUE,
	                    output      SDO,
	                    input       SDI,
	                    input       SCLK
                      );
	 parameter                      FEEDBACK_PATH = "SIMPLE";
	 parameter                      DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
	 parameter                      DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
	 parameter                      SHIFTREG_DIV_MODE = 1'b0;
	 parameter                      FDA_FEEDBACK = 4'b0000;
	 parameter                      FDA_RELATIVE = 4'b0000;
	 parameter                      PLLOUT_SELECT = "GENCLK";
	 parameter                      DIVR = 4'b0000;
	 parameter                      DIVF = 7'b0000000;
	 parameter                      DIVQ = 3'b000;
	 parameter                      FILTER_RANGE = 3'b000;
	 parameter                      ENABLE_ICEGATE = 1'b0;
	 parameter                      TEST_MODE = 1'b0;
	 parameter                      EXTERNAL_DIVIDE_FACTOR = 1;

   localparam                     CLK_RATIO = (DIVF+1)/(2**DIVQ*(DIVR+1));

   time                           ref_per;
   time                           clk_per;
   time                           last_ref_rising;

   integer                        timeout;

   reg                            clk;
   reg                            lock_reg;

   assign #(clk_per/4) PLLOUTGLOBAL = clk; // glitch filter
   assign #(clk_per+ref_per) LOCK = lock_reg; // glitch filter

   initial begin
      ref_per = 0;
      clk_per = 10;
      last_ref_rising = $time;
      clk = 0;
      lock_reg = 1;
      timeout = 4*CLK_RATIO;
      #1 lock_reg = 0; // negedge to trigger reset
      #100;
      ref_per = 0;
      clk_per = 100000000;
   end

   always @(posedge REFERENCECLK) begin
      if (`abs($time - last_ref_rising - ref_per)*100/ref_per < 1)
        lock_reg = 1;
      else
        lock_reg = 0;
      ref_per = $time - last_ref_rising;
      last_ref_rising = $time;
      if (clk_per != 2**DIVQ * (DIVR + 1) * ref_per / (DIVF + 1)) begin
         clk_per = 2**DIVQ * (DIVR + 1) * ref_per / (DIVF + 1);
         clk <= ~clk;
      end
      timeout = 4*CLK_RATIO;
   end

   always @(clk)
     if (timeout > 0) begin
        clk <= #(clk_per/2) ~clk;
        if (clk)
          timeout = timeout - 1;
     end else
       lock_reg = 0;
endmodule

