//  USB 2.0 full speed IN FIFO.
//  Written in verilog 2001

// IN_FIFO module shall implement IN FIFO interface.
// While IN FIFO is not empty, when required by in_req_i, IN_FIFO
//   shall source IN data.

module in_fifo
  #(parameter IN_MAXPACKETSIZE = 'd8,
    parameter BIT_SAMPLES = 'd4,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_RATIO = 'd4)
   (
    // ---- to/from Application ------------------------------------
    input        app_clk_i,
    input        app_rstn_i,
    // While app_rstn_i is low (active low), the app_clk_i'ed registers shall be reset
    input [7:0]  app_in_data_i,
    input        app_in_valid_i,
    // While app_in_valid_i is high, app_in_data_i shall be valid.
    output       app_in_ready_o,
    // When both app_in_ready_o and app_in_valid_i are high, app_in_data_i shall
    //   be consumed.

    // ---- from top module ---------------------------------------
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
    input        rstn_i,
    // While rstn_i is low (active low), the clk_i'ed registers shall be reset
    output       in_empty_o,
    output       in_full_o,

    // ---- to/from SIE module ------------------------------------
    output [7:0] in_data_o,
    // While in_valid_o is high, in_data_o shall be valid.
    output       in_valid_o,
    // While in_req_i is high and IN FIFO is not empty, in_valid_o shall be high.
    input        in_req_i,
    // When a new IN transaction is requested, in_req_i shall change from low to high.
    // When a IN transaction ends, in_req_i shall change from high to low.
    input        in_ready_i,
    // When both in_ready_i and in_valid_o are high, in_data_o shall be consumed.
    // When in_data_o is consumed, in_ready_i shall be high only for
    //   one clk_i period.
    input        in_data_ack_i,
    input        out_valid_i,
    input        out_ready_i
    // When in_data_ack_i is high and out_ready_i is high, an ACK packet shall be received.
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   localparam                      IN_LENGTH = IN_MAXPACKETSIZE + 'd1;
   localparam                      ST_IN_IDLE = 1'b0,
                                   ST_IN_DATA = 1'b1;

   reg [8*IN_LENGTH-1:0]           in_fifo_q;
   reg [ceil_log2(IN_LENGTH)-1:0]  in_last_q;
   reg [ceil_log2(IN_LENGTH)-1:0]  in_first_q;
   reg [ceil_log2(IN_LENGTH)-1:0]  in_first_qq;
   reg                             in_state_q;
   reg                             in_req_q;
   reg                             in_valid_q;

   assign in_data_o = in_fifo_q[8*in_first_qq +:8];
   assign in_valid_o = in_valid_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_req_q <= 1'b0;
         in_state_q <= ST_IN_IDLE;
         in_valid_q <= 1'b0;
      end else begin
         in_req_q <= in_req_i;
         if (in_state_q == ST_IN_IDLE) begin
            if (in_req_i == 1'b1)
              in_state_q <= ST_IN_DATA;
         end else begin
            if (out_valid_i == 1'b1 || out_ready_i == 1'b1)
              in_state_q <= ST_IN_IDLE;
         end
         if (in_req_q == 1'b0) begin
            if (in_req_i == 1'b1 && in_first_q != in_last_q)
              in_valid_q <= 1'b1;
            else
              in_valid_q <= 1'b0;
         end else begin
            if (in_first_qq == in_last_q)
              in_valid_q <= 1'b0;
         end
      end
   end

   wire                           in_start;
   wire                           in_clk_gate;

   assign in_start = (in_req_q == 1'b0 && in_req_i == 1'b1) ? 1'b1 : 1'b0;
   assign in_clk_gate = in_ready_i | out_ready_i | in_start;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_first_q <= 'd0;
         in_first_qq <= 'd0;
      end else begin
         if (in_clk_gate) begin
            if (in_req_q == 1'b0) begin
               if (in_req_i == 1'b1)
                 in_first_qq <= in_first_q; // shall retry one more time if in_first_q wasn't updated
               else if (in_state_q == ST_IN_DATA && in_data_ack_i == 1'b1)
                 in_first_q <= in_first_qq;
            end else begin
               if (in_first_qq == IN_LENGTH-1)
                 in_first_qq <= 'd0;
               else
                 in_first_qq <= in_first_qq + 1;
            end
         end
      end
   end

   reg [ceil_log2(BIT_SAMPLES)-1:0] delay_in_cnt_q;

   wire                             in_full;

   assign in_empty_o = ((in_first_q == in_last_q) ? 1'b1 : 1'b0);
   assign in_full = (in_last_q == ((in_first_q == 'd0) ? IN_LENGTH-1: in_first_q-1) ? 1'b1 : 1'b0);
   assign in_full_o = in_full;

   generate
      if (USE_APP_CLK == 0) begin : u_sync_data
         assign app_in_ready_o = ((in_full == 1'b0 && {1'b0, delay_in_cnt_q} == BIT_SAMPLES-1) ? 1'b1 : 1'b0);

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               delay_in_cnt_q <= 'd0;
            end else begin
               if ({1'b0, delay_in_cnt_q} != BIT_SAMPLES-1) begin
                  delay_in_cnt_q <= delay_in_cnt_q + 1;
               end else begin
                  if (in_full == 1'b0) begin
                     if (app_in_valid_i == 1'b1) begin
                        in_fifo_q[8*in_last_q +:8] <= app_in_data_i;
                        delay_in_cnt_q <= 'd0;
                        if (in_last_q == IN_LENGTH-1)
                          in_last_q <= 'd0;
                        else
                          in_last_q <= in_last_q + 1;
                     end
                  end
               end
            end
         end
      end else if (APP_CLK_RATIO >= 4) begin : u_gtex4_async_data
         reg [2:0] app_clk_sq;
         reg [7:0] in_data_q;
         reg       in_ready_q;
         reg       in_consumed_q;

         assign app_in_ready_o = in_ready_q;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               delay_in_cnt_q <= 'd0;
               in_ready_q <= 1'b0;
               app_clk_sq <= 3'd0;
            end else begin
               app_clk_sq <= {app_clk_i, app_clk_sq[2:1]};
               if ({1'b0, delay_in_cnt_q} != BIT_SAMPLES-1) begin
                  delay_in_cnt_q <= delay_in_cnt_q + 1;
               end else begin
                  if (in_full == 1'b0) begin
                     if (app_clk_sq[1:0] == 2'b10) begin
                        in_ready_q <= 1'b1;
                        if (in_consumed_q == 1'b1) begin
                           in_fifo_q[8*in_last_q +:8] <= in_data_q;
                           delay_in_cnt_q <= 'd0;
                           in_ready_q <= 1'b0;
                           if (in_last_q == IN_LENGTH-1)
                             in_last_q <= 'd0;
                           else
                             in_last_q <= in_last_q + 1;
                        end
                     end
                     if (APP_CLK_RATIO >= 8 && app_clk_sq[1:0] == 2'b01) begin
                        in_ready_q <= 1'b1;
                     end
                  end
               end
            end
         end

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               in_consumed_q <= 1'b0;
               in_data_q <= 8'd0;
            end else begin
               in_consumed_q <= app_in_valid_i & in_ready_q;
               if (app_in_valid_i == 1'b1 && in_ready_q == 1'b1)
                 in_data_q <= app_in_data_i;
            end
         end
      end else begin : u_ltx4_async_data
         reg [1:0] in_ovalid_sq;
         reg       in_ovalid_mask_q;
         reg       in_iready_mask_q;
         reg [7:0] in_data_q;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               delay_in_cnt_q <= 'd0;
               in_ovalid_sq <= 2'd0;
               in_ovalid_mask_q <= 1'b0;
            end else begin
               in_ovalid_sq <= {in_iready_mask_q, in_ovalid_sq[1]};
               if ({1'b0, delay_in_cnt_q} != BIT_SAMPLES-1) begin
                  delay_in_cnt_q <= delay_in_cnt_q + 1;
               end else begin
                  if (~in_ovalid_sq[0])
                    in_ovalid_mask_q <= 1'b0;
                  else if (~in_full & ~in_ovalid_mask_q) begin
                     in_ovalid_mask_q <= 1'b1;
                     in_fifo_q[8*in_last_q +:8] <= in_data_q;
                     delay_in_cnt_q <= 'd0;
                     if (in_last_q == IN_LENGTH-1)
                       in_last_q <= 'd0;
                     else
                       in_last_q <= in_last_q + 1;
                  end
               end
            end
         end

         reg [1:0] in_iready_sq;

         assign app_in_ready_o = in_iready_sq[0] & ~in_iready_mask_q;

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               in_iready_sq <= 2'b00;
               in_iready_mask_q <= 1'b0;
               in_data_q <= 8'd0;
            end else begin
               in_iready_sq <= {~in_ovalid_mask_q, in_iready_sq[1]};
               if (~in_iready_sq[0])
                 in_iready_mask_q <= 1'b0;
               else if (app_in_valid_i & ~in_iready_mask_q) begin
                  in_data_q <= app_in_data_i;
                  in_iready_mask_q <= 1'b1;
               end
            end
         end
      end
   endgenerate
endmodule
