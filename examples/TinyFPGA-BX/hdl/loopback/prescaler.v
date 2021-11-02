
module prescaler
  (
   input  clk_i,
   input  rstn_i,
   output clk_div16_o,
   output clk_div8_o,
   output clk_div4_o,
   output clk_div2_o
   );

   reg [3:0] prescaler_cnt;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         prescaler_cnt <= 'd0;
      end else begin
         prescaler_cnt <= prescaler_cnt + 1;
      end
   end

   assign clk_div16_o = prescaler_cnt[3];
   assign clk_div8_o = prescaler_cnt[2];
   assign clk_div4_o = prescaler_cnt[1];
   assign clk_div2_o = prescaler_cnt[0];
   
endmodule
