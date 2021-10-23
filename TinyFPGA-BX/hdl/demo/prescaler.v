
module prescaler
  (
   input  clk_16mhz_i,
   input  rstn_i,
   output clk_1mhz_o,
   output clk_2mhz_o,
   output clk_4mhz_o,
   output clk_8mhz_o
   );

   reg [3:0] prescaler_cnt;

   always @(posedge clk_16mhz_i or negedge rstn_i) begin
      if (~rstn_i) begin
         prescaler_cnt <= 'd0;
      end else begin
         prescaler_cnt <= prescaler_cnt + 1;
      end
   end

   assign clk_1mhz_o = prescaler_cnt[3];
   assign clk_2mhz_o = prescaler_cnt[2];
   assign clk_4mhz_o = prescaler_cnt[1];
   assign clk_8mhz_o = prescaler_cnt[0];
   
endmodule
