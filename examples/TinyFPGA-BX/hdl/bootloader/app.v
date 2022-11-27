// APP module shall implement an example of bootloader.
// APP shall provide access to tinyprog to the FLASH.

`define max(a,b)((a) > (b) ? (a) : (b))

module app
  (
   input        clk_i,
   input        rstn_i,

   // ---- to/from USB_CDC ------------------------------------------
   output [7:0] in_data_o,
   output       in_valid_o,
   // While in_valid_o is high, in_data_o shall be valid.
   input        in_ready_i,
   // When both in_ready_i and in_valid_o are high, in_data_o shall
   //   be consumed.
   input [7:0]  out_data_i,
   input        out_valid_i,
   // While out_valid_i is high, the out_data_i shall be valid and both
   //   out_valid_i and out_data_i shall not change until consumed.
   output       out_ready_o,
   // When both out_valid_i and out_ready_o are high, the out_data_i shall
   //   be consumed.
   input        heartbeat_i,
   output       boot_o,
   output       sck_o,
   output       csn_o,
   output       mosi_o,
   input        miso_i
   );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   reg [1:0]         rstn_sq;

   wire              rstn;

   assign rstn = rstn_sq[0];

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rstn_sq <= 2'd0;
      end else begin
         rstn_sq <= {1'b1, rstn_sq[1]};
      end
   end

   localparam [2:0] ST_IDLE = 3'd0,
                    ST_WR_LO_LENGTH = 3'd1,
                    ST_WR_HI_LENGTH = 3'd2,
                    ST_RD_LO_LENGTH = 3'd3,
                    ST_RD_HI_LENGTH = 3'd4,
                    ST_WR_DATA = 3'd5,
                    ST_RD_DATA = 3'd6,
                    ST_BOOT = 3'd7;
   localparam       TIMER_MSB = ceil_log2(2*16000000); // 2 sec

   reg [2:0]        state_q, state_d;
   reg [15:0]       wr_length_q, wr_length_d;
   reg [15:0]       rd_length_q, rd_length_d;
   reg [TIMER_MSB:0] timer_q, timer_d;
   reg [2:0]         heartbeat_sq;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         state_q <= ST_IDLE;
         wr_length_q <= 'd0;
         rd_length_q <= 'd0;
         timer_q <= 'd0;
         heartbeat_sq <= 3'd0;
      end else begin
         state_q <= state_d;
         wr_length_q <= wr_length_d;
         rd_length_q <= rd_length_d;
         timer_q <= timer_d;
         heartbeat_sq <= {heartbeat_i, heartbeat_sq[2:1]};
      end
   end

   reg        en;
   reg        wr_valid;
   reg        rd_ready;
   reg        in_valid;
   reg        out_ready;
   reg        boot;

   wire       wr_ready;
   wire [7:0] rd_data;
   wire       rd_valid;

   assign in_data_o = rd_data;
   assign in_valid_o = in_valid;
   assign out_ready_o = out_ready;
   assign boot_o = boot;

   always @(/*AS*/heartbeat_sq or in_ready_i or out_data_i
            or out_valid_i or rd_length_q or rd_valid or state_q
            or timer_q or wr_length_q or wr_ready) begin
      state_d = state_q;
      wr_length_d = wr_length_q;
      rd_length_d = rd_length_q;
      if (heartbeat_sq[1] != heartbeat_sq[0])
        timer_d = 'd0;
      else
        timer_d = timer_q + 1;
      en = 1'b0;
      wr_valid = 1'b0;
      rd_ready = 1'b0;
      in_valid = 1'b0;
      out_ready = 1'b0;
      boot = 1'b0;

      if (timer_q[TIMER_MSB])
        state_d = ST_BOOT;

      case (state_q)
        ST_IDLE : begin
           out_ready = 1'b1;
           if (out_valid_i == 1'b1) begin
              if (out_data_i == 8'h00)
                state_d = ST_BOOT;
              else if (out_data_i == 8'h01)
                state_d = ST_WR_LO_LENGTH;
           end
        end
        ST_WR_LO_LENGTH : begin
           out_ready = 1'b1;
           if (out_valid_i == 1'b1) begin
              state_d = ST_WR_HI_LENGTH;
              wr_length_d[7:0] = out_data_i;
           end
        end
        ST_WR_HI_LENGTH : begin
           out_ready = 1'b1;
           if (out_valid_i == 1'b1) begin
              state_d = ST_RD_LO_LENGTH;
              wr_length_d[15:8] = out_data_i;
           end
        end
        ST_RD_LO_LENGTH : begin
           out_ready = 1'b1;
           if (out_valid_i == 1'b1) begin
              state_d = ST_RD_HI_LENGTH;
              rd_length_d[7:0] = out_data_i;
           end
        end
        ST_RD_HI_LENGTH : begin
           out_ready = 1'b1;
           if (out_valid_i == 1'b1) begin
              state_d = ST_WR_DATA;
              rd_length_d[15:8] = out_data_i;
           end
        end
        ST_WR_DATA : begin
           en = 1'b1;
           if (wr_length_q == 'd0) begin
              if (rd_length_q == 'd0)
                state_d = ST_IDLE;
              else if (rd_valid)
                state_d = ST_RD_DATA;
           end else begin
              wr_valid = out_valid_i;
              out_ready = wr_ready;
              if (wr_ready & out_valid_i)
                wr_length_d = wr_length_q - 1;
           end
        end
        ST_RD_DATA : begin
           en = 1'b1;
           if (rd_length_q == 'd0) begin
              state_d = ST_IDLE;
           end else begin
              in_valid = rd_valid;
              rd_ready = in_ready_i;
              if (rd_valid & in_ready_i)
                rd_length_d = rd_length_q - 1;
           end
        end
        ST_BOOT : begin
           boot = 1'b1;
        end
        default : begin
           state_d = ST_IDLE;
        end
      endcase
   end

   spi #(.SCK_PERIOD_MULTIPLIER('d2))
   u_spi (.clk_i(clk_i),
          .rstn_i(rstn),
          .en_i(en),
          .wr_data_i(out_data_i),
          .wr_valid_i(wr_valid),
          .wr_ready_o(wr_ready),
          .rd_data_o(rd_data),
          .rd_valid_o(rd_valid),
          .rd_ready_i(rd_ready),
          .sck_o(sck_o),
          .csn_o(csn_o),
          .mosi_o(mosi_o),
          .miso_i(miso_i));
endmodule
