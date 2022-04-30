//  USB 2.0 full speed transmitter physical layer.
//  Written in verilog 2001

// PHY_TX module shall manage physical layer signaling of USB 2.0
//   full speed transmitter (USB2.0 Chap. 7):
//   - Start-Of-Packet (SOP) and Sync Pattern generation.
//   - NRZI Data encoding.
//   - Bit Stuffing insertion.
//   - End-Of-Packet (EOP) generation.
// PHY_TX module shall convert 8-bit parallel data from the SIE
//   module to bitstream for the USB bus physical transmitters.

module phy_tx
  #(parameter BIT_SAMPLES = 'd4)
   (
    // ---- to USB bus physical transmitters ----------------------
    output      tx_en_o,
    output      dp_tx_o,
    output      dn_tx_o,
    // dp_tx_o and dn_tx_o shall have a negligible timing mismatch
    //   (< clk_i period /2).

    // ---- to/from SIE module ------------------------------------
    output      tx_ready_o,
    // When both tx_valid_i and tx_ready_o are high, the 8-bit tx_data_i shall be consumed.
    // When tx_data_i is consumed, tx_ready_o shall be high only for one clk_i period.
    input       clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input       rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    input       tx_valid_i,
    // When tx_valid_i changes from low to high, PHY_TX shall start a
    //   new packet transmission as soon as possible (USB2.0 7.1.18.1).
    // When the last packet byte is consumed, tx_valid_i shall return low.
    input [7:0] tx_data_i
    // While tx_valid_i is high, the tx_data_i shall be valid and both
    //   tx_valid_i and tx_data_i shall not change until consumed.
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   localparam [1:0] ST_IDLE = 2'd0,
                    ST_SYNC = 2'd1,
                    ST_DATA = 2'd2,
                    ST_EOP = 2'd3;

   reg [ceil_log2(BIT_SAMPLES)-1:0] clk_cnt_q;
   reg [1:0]                        tx_state_q, tx_state_d;
   reg [2:0]                        bit_cnt_q, bit_cnt_d;
   reg [7:0]                        data_q, data_d;
   reg [2:0]                        stuffing_cnt_q, stuffing_cnt_d;
   reg                              nrzi_q, nrzi_d;
   reg                              tx_valid_q;
   reg                              tx_ready;

   wire                             clk_gate;

   assign tx_en_o = (tx_state_q == ST_IDLE) ? 1'b0 : 1'b1;
   assign dp_tx_o = (tx_state_q == ST_EOP && data_q[0] == 1'b0) ? 1'b0 : nrzi_q;
   assign dn_tx_o = (tx_state_q == ST_EOP && data_q[0] == 1'b0) ? 1'b0 : ~nrzi_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         clk_cnt_q <= 'd0;
      end else begin
         if (tx_state_q == ST_IDLE && tx_valid_i == 1'b0)
           clk_cnt_q <= 'd0;
         else begin
            if ({1'b0, clk_cnt_q} == BIT_SAMPLES-1)
              clk_cnt_q <= 'd0;
            else
              clk_cnt_q <= clk_cnt_q + 1;
         end
      end
   end

   assign clk_gate = ({1'b0, clk_cnt_q} == BIT_SAMPLES-1) ? 1'b1 : 1'b0;
   assign tx_ready_o = clk_gate & tx_ready;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         tx_state_q <= ST_IDLE;
         bit_cnt_q <= 3'd7;
         data_q <= 8'b10000000;
         stuffing_cnt_q <= 3'd0;
         nrzi_q <= 1'b1;
         tx_valid_q <= 1'b0;
      end else begin
         if (clk_gate) begin
            tx_state_q <= tx_state_d;
            bit_cnt_q <= bit_cnt_d;
            data_q <= data_d;
            stuffing_cnt_q <= stuffing_cnt_d;
            nrzi_q <= nrzi_d;
            tx_valid_q <= tx_valid_i;
         end
      end
   end

   always @(/*AS*/bit_cnt_q or data_q or nrzi_q or stuffing_cnt_q
            or tx_data_i or tx_state_q or tx_valid_q) begin
      tx_state_d = tx_state_q;
      bit_cnt_d = bit_cnt_q;
      data_d = data_q;
      stuffing_cnt_d = stuffing_cnt_q;
      nrzi_d = nrzi_q;
      tx_ready = 1'b0;

      if (stuffing_cnt_q == 3'd6) begin
         stuffing_cnt_d = 3'd0;
         nrzi_d = ~nrzi_q;
      end else begin
         bit_cnt_d = bit_cnt_q - 1;
         data_d = (data_q >> 1);
         if (data_q[0] == 1'b1) begin
            stuffing_cnt_d = stuffing_cnt_q + 1;
         end else begin
            stuffing_cnt_d = 3'd0;
            nrzi_d = ~nrzi_q;
         end
         case (tx_state_q)
           ST_IDLE : begin
              if (tx_valid_q == 1'b1) begin
                 tx_state_d = ST_SYNC;
              end else begin
                 bit_cnt_d = 3'd7;
                 data_d = 8'b10000000;
                 nrzi_d = 1'b1;
              end
              stuffing_cnt_d = 3'd0;
           end
           ST_SYNC : begin
              if (bit_cnt_q == 3'd0)
                if (tx_valid_q == 1'b1) begin
                   tx_state_d = ST_DATA;
                   bit_cnt_d = 3'd7;
                   data_d = tx_data_i;
                   tx_ready = 1'b1;
                end else begin
                   tx_state_d = ST_IDLE;
                   bit_cnt_d = 3'd7;
                   data_d = 8'b10000000;
                   stuffing_cnt_d = 3'd0;
                   nrzi_d = 1'b1;
                end
           end
           ST_DATA : begin
              if (bit_cnt_q == 3'd0)
                if (tx_valid_q == 1'b1) begin
                   bit_cnt_d = 3'd7;
                   data_d = tx_data_i;
                   tx_ready = 1'b1;
                end else begin
                   tx_state_d = ST_EOP;
                   bit_cnt_d = 3'd3;
                   data_d = 8'b11111001;
                end
           end
           ST_EOP : begin
              if (bit_cnt_q == 3'd0) begin
                 tx_state_d = ST_IDLE;
                 bit_cnt_d = 3'd7;
                 data_d = 8'b10000000;
              end
              stuffing_cnt_d = 3'd0;
              nrzi_d = 1'b1;
           end
           default : begin
              tx_state_d = ST_IDLE;
              bit_cnt_d = 3'd7;
              data_d = 8'b10000000;
              stuffing_cnt_d = 3'd0;
              nrzi_d = 1'b1;
           end
         endcase
      end
   end
endmodule
