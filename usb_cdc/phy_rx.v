//  USB 2.0 full speed receiver physical layer.
//  Written in verilog 2001

// PHY_RX module shall manage physical layer signaling of USB 2.0
//   full speed receiver (USB2.0 Chap. 7):
//   - Start-Of-Packet (SOP) and Sync Pattern detection.
//   - NRZI Data decoding.
//   - Bit Stuffing removal.
//   - End-Of-Packet (EOP) detection.
//   - USB Reset detection.
// PHY_RX module shall convert bitstream from the USB bus physical receivers 
//   to 8-bit parallel data for the SIE module.
// PHY_RX module shall manage the 1.5kOhm pull-up resistor on dp line.

module phy_rx
  #(parameter BIT_SAMPLES = 'd4)
   (
    // ---- to/from SIE module ------------------------------------
    output [7:0] rx_data_o,
    output       rx_valid_o,
    // While a new data byte is shifting in, rx_valid_o shall be high, otherwise
    //   shall be low.
    // When both rx_valid_o and rx_ready_o are high, rx_data_o shall be valid and
    //   shall be consumed by SIE module.
    output       rx_err_o,
    // When both rx_err_o and rx_ready_o are high, PHY_RX module shall abort the
    //   current packet reception and SIE module shall manage the error condition.
    output       usb_reset_o,
    // When dp_rx_i/dn_rx_i change and stay in SE0 condition for 2.5us, usb_reset_o shall be high.
    // When dp_rx_i/dn_rx_i change from SE0 condition, usb_reset_o shall return low
    //   after being high for at least 330ns.
    // When usb_detach_i is high and a usb detach has started, usb_reset_o shall be high.
    output       rx_ready_o,
    // rx_ready_o shall be high only for one clk_i period.
    // While rx_valid_o and rx_err_o are both low, rx_ready_o shall be high to signal the
    //   end of packet (EOP).
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input        rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    input        rx_en_i,
    // While rx_en_i is low, the module shall be disabled.
    // When rx_en_i changes from low to high, the module shall start to monitor dp/dn lines
    //   for the start of a new packet.
    input        usb_detach_i,
    // When usb_detach_i is high, a usb detach shall be requested.

    // ---- to/from USB bus ------------------------------------------
    output       dp_pu_o,
    // While dp_pu_o is high, a 1.5KOhm resistor shall pull-up the dp line.
    // At power-on or when usb_detach_i is high, dp_pu_o shall be low.
    // After TSIGATT time from power-on or from usb_detach_i change to low, dp_pu_o shall be high.
    input        dp_rx_i,
    input        dn_rx_i
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   reg [2:0] dp_q, dn_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         dp_q <= 3'b000;
         dn_q <= 3'b000;
      end else begin
         dp_q <= {dp_rx_i, dp_q[2:1]};
         dn_q <= {dn_rx_i, dn_q[2:1]};
      end
   end

   localparam [1:0] SE0 = 2'd0,
                    DJ = 2'd1,
                    DK = 2'd2,
                    SE1 = 2'd3;
   reg [1:0]        nrzi;

   always @(/*AS*/dn_q or dp_q) begin
      if (dp_q[0] == 1'b1 && dn_q[0] == 1'b0)
        nrzi = DJ;
      else if (dp_q[0] == 1'b0 && dn_q[0] == 1'b1)
        nrzi = DK;
      else if (dp_q[0] == 1'b0 && dn_q[0] == 1'b0)
        nrzi = SE0;
      else // dp or dn at 1'bX too
        nrzi = SE1;
   end

   reg [ceil_log2(BIT_SAMPLES)-1:0] clk_cnt_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         clk_cnt_q <= 'd0;
      end else begin
         if (dp_q[1] == dp_q[0] && dn_q[1] == dn_q[0]) begin
            if ({1'b0, clk_cnt_q} == BIT_SAMPLES-1)
              clk_cnt_q <= 'd0;
            else
              clk_cnt_q <= clk_cnt_q + 1;
         end else begin // dp or dn at 1'bX too
            clk_cnt_q <= 'd0;
         end
      end
   end

   localparam [2:0] ST_IDLE = 3'd0,
                    ST_SYNC = 3'd1,
                    ST_DATA = 3'd2,
                    ST_EOP = 3'd3,
                    ST_ERR = 3'd4;
   localparam       CNT_WIDTH = ceil_log2((2**14+1)*12);

   reg [3:0]        nrzi_q;
   reg [2:0]        rx_state_q, rx_state_d;
   reg [8:0]        data_q, data_d;
   reg [2:0]        stuffing_cnt_q, stuffing_cnt_d;
   reg              rx_valid_rq, rx_valid_rd;
   reg              rx_valid_fq, rx_valid_fd;
   reg [CNT_WIDTH-1:0] cnt_q;
   reg                 dp_pu_q;
   reg                 rx_en_q;

   wire                rx_ready;
   wire                rx_err;
   wire                rx_eop;
   wire                clk_gate;

   localparam          VALID_SAMPLES = BIT_SAMPLES/2; // consecutive valid samples

   assign clk_gate = ({1'b0, clk_cnt_q} == (VALID_SAMPLES-1)) ? 1'b1 : 1'b0;
   assign rx_ready = (data_q[0] == 1'b1 && stuffing_cnt_q != 3'd6) ? 1'b1 : 1'b0;
   assign rx_err = (rx_state_q == ST_ERR) ? 1'b1 : 1'b0;
   assign rx_eop = (rx_state_q == ST_EOP && nrzi_q[3:2] == DJ) ? 1'b1 : 1'b0;

   assign rx_ready_o = clk_gate & (rx_ready | rx_err | rx_eop);
   // rx_valid_o put to 0 early to gain setup time before rx_eop
   assign rx_valid_o = rx_valid_rq ^ rx_valid_fq;
   assign rx_err_o = rx_err;
   assign usb_reset_o = (rx_en_q & cnt_q[5]) | (usb_detach_i & ~rx_en_q & ~dp_pu_q);
   assign rx_data_o = data_q[8:1];
   assign dp_pu_o = dp_pu_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         nrzi_q <= {SE0, SE0};
         rx_state_q <= ST_IDLE;
         data_q <= 9'b100000000;
         stuffing_cnt_q <= 3'd0;
         rx_valid_rq <= 1'b0;
         rx_valid_fq <= 1'b0;
         cnt_q <= 'd0;
         dp_pu_q <= 1'b0;
         rx_en_q <= 1'b0;
      end else begin
         if (clk_gate) begin
            nrzi_q <= {nrzi, nrzi_q[3:2]};
            if (rx_en_i & rx_en_q)
              rx_state_q <= rx_state_d;
            else
              rx_state_q <= ST_IDLE;
            data_q <= data_d;
            stuffing_cnt_q <= stuffing_cnt_d;
            rx_valid_rq <= rx_valid_rd;
            if (rx_ready == 1'b1 && nrzi == SE0)
              rx_valid_fq <= rx_valid_rq;
            else
              rx_valid_fq <= rx_valid_fd;
            if (cnt_q[CNT_WIDTH-1 -:2] == 2'b11) begin
               dp_pu_q <= 1'b1; // TSIGATT=16ms < 100ms (USB2.0 Tab.7-14 pag.188)
               if (cnt_q[CNT_WIDTH-1-8 -:2] == 2'b11)
                 rx_en_q <= 1'b1; // 16ms + 64us
            end
            if (usb_detach_i) begin
               dp_pu_q <= 1'b0;
               rx_en_q <= 1'b0;
               cnt_q <= 'd0;
            end else if (~rx_en_q) begin
               cnt_q <= cnt_q + 1;
            end else begin
               if (cnt_q[5] == 1'b1) begin // 2.5us < TDETRST=2.67us < 10ms (USB2.0 Tab.7-14 pag.188)
                  if (cnt_q[2] == 1'b0)
                    cnt_q <= cnt_q + 1;
                  else if (nrzi_q[3:2] != SE0)
                    cnt_q <= 'd0;
               end else if (nrzi_q[3:2] == SE0)
                 cnt_q <= cnt_q + 1;
               else
                 cnt_q <= 'd0;
            end
         end
      end
   end

   always @(/*AS*/data_q or nrzi_q or rx_state_q or rx_valid_fq
            or rx_valid_rq or stuffing_cnt_q) begin
      rx_state_d = rx_state_q;
      data_d = 9'b100000000;
      stuffing_cnt_d = 3'd0;
      rx_valid_rd = rx_valid_rq;
      rx_valid_fd = rx_valid_fq;

      case (rx_state_q)
        ST_IDLE : begin
           if (nrzi_q[1:0] == DJ && nrzi_q[3:2] == DK) begin
              rx_state_d = ST_SYNC;
           end
        end
        ST_SYNC : begin
           if ((nrzi_q[3:2] == SE1) || (nrzi_q[3:2] == SE0)) begin
              rx_state_d = ST_IDLE;
           end else begin
              if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                 if (data_q[8:3] == 6'b000000 && nrzi_q[3:2] == DK) begin
                    rx_state_d = ST_DATA;
                    rx_valid_rd = ~rx_valid_rq;
                    stuffing_cnt_d = stuffing_cnt_q + 1;
                 end else begin
                    rx_state_d = ST_IDLE;
                 end
              end else begin
                 data_d = {1'b0, data_q[8:1]};
              end
           end
        end
        ST_DATA : begin
           if (nrzi_q[3:2] == SE1) begin
              rx_state_d = ST_ERR;
              rx_valid_fd = rx_valid_rq;
           end else if (nrzi_q[3:2] == SE0) begin
              // 1 or 2 SE0s for EOP: USB2.0 Tab.7-2 pag.145
              // dribble bit: USB2.0 Fig.7-33 pag.158
              if (data_q == 9'b110000000) begin
                 rx_state_d = ST_EOP;
              end else if (data_q[0] == 1'b1 && stuffing_cnt_q != 3'd6) begin
                 data_d = 9'b110000000;
              end else begin
                 rx_state_d = ST_ERR;
                 rx_valid_fd = rx_valid_rq;
              end
           end else if (nrzi_q[1:0] == SE0) begin
              rx_state_d = ST_ERR;
              rx_valid_fd = rx_valid_rq;
           end else if (stuffing_cnt_q == 3'd6) begin
              if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                 rx_state_d = ST_ERR;
                 rx_valid_fd = rx_valid_rq;
              end else begin
                 data_d = data_q;
              end
           end else begin
              if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                 data_d[8] = 1'b1;
                 stuffing_cnt_d = stuffing_cnt_q + 1;
              end else begin
                 data_d[8] = 1'b0;
              end
              if (data_q[0] == 1'b1) begin
                 data_d[7:0] = 8'b10000000;
              end else begin
                 data_d[7:0] = data_q[8:1];
              end
           end
        end
        ST_EOP : begin
           if (nrzi_q[3:2] == DJ) begin
              rx_state_d = ST_IDLE;
           end else begin
              rx_state_d = ST_ERR;
              rx_valid_fd = rx_valid_rq;
           end
        end
        ST_ERR : begin
           rx_state_d = ST_IDLE;
        end
        default : begin
           rx_state_d = ST_ERR;
           rx_valid_fd = rx_valid_rq;
        end
      endcase
   end
endmodule
