//  USB 2.0 full speed receiver physical layer.
//  Written in verilog 2001

// PHY_RX module shall manage physical layer signaling of USB 2.0
//   full speed receiver (USB2.0 Chap. 7):
//   - Start-Of-Packet (SOP) and Sync Pattern detection.
//   - NRZI Data decoding.
//   - Bit Stuffing removal.
//   - End-Of-Packet (EOP) detection.
//   - Bus Reset detection.
// PHY_RX module shall convert bitstream from the USB bus physical receivers 
//   to 8-bit parallel data for the SIE module.
// PHY_RX module shall manage the 1.5kOhm pull-up resistor on dp line.

module phy_rx
  #(parameter BIT_SAMPLES = 'd4)
   (
    // ---- to/from SIE module ------------------------------------
    output [7:0] rx_data_o,
    // While rx_valid_o is high, the rx_data_o shall be valid and both
    //   rx_valid_o and rx_data_o shall not change until consumed.
    output       rx_valid_o,
    // When both rx_valid_o and rx_ready_o are high, rx_data_o shall be consumed by SIE module.
    // When clk_gate_i is high, rx_valid_o shall be updated.
    output       rx_err_o,
    // When both rx_err_o and rx_ready_o are high, PHY_RX module shall abort the
    //   current packet reception and SIE module shall manage the error condition.
    // When clk_gate_i is high, rx_err_o shall be updated.
    output       bus_reset_o,
    // When dp_rx_i/dn_rx_i change and stay in SE0 condition for 2.5us, bus_reset_o shall be high.
    // When dp_rx_i/dn_rx_i change from SE0 condition, bus_reset_o shall return low.
    // While usb_detach_i is high and a usb detach has started, bus_reset_o shall be high.
    // When clk_gate_i is high, bus_reset_o shall be updated.
    output       rx_ready_o,
    // rx_ready_o shall be high only for one clk_gate_i multi-cycle period.
    // While rx_valid_o and rx_err_o are both low, rx_ready_o shall be high to signal the
    //   end of packet (EOP).
    // When clk_gate_i is high, rx_ready_o shall be updated.
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input        rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    input        clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.
    input        rx_en_i,
    // While rx_en_i is low, the module shall be disabled.
    // When rx_en_i changes from low to high, the module shall start monitoring the dp/dn
    //   lines for the beginning of a new packet.
    // When clk_gate_i is high, rx_en_i shall be updated.
    input        usb_detach_i,
    // When usb_detach_i is high, a USB detach process shall be initiated.
    // When usb_detach_i changes from high to low, the attaching timing process shall begin.
    // When clk_gate_i is high, usb_detach_i shall be updated.

    // ---- to/from USB bus ------------------------------------------
    output       dp_pu_o,
    // While dp_pu_o is high, a 1.5KOhm resistor shall pull-up the dp line.
    // At power-on or when usb_detach_i is high, dp_pu_o shall be low.
    // After TSIGATT time from power-on or from usb_detach_i change to low, dp_pu_o shall be high.
    input        dp_rx_i,
    input        dn_rx_i
    );

   function integer ceil_log2;
      input [31:0] arg;
      integer      i;
      begin
         ceil_log2 = 0;
         for (i = 0; i < 32; i = i + 1) begin
            if (arg > (1 << i))
              ceil_log2 = ceil_log2 + 1;
         end
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

   reg [ceil_log2(BIT_SAMPLES)-1:0] sample_cnt_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         sample_cnt_q <= 'd0;
      end else begin
         if (dp_q[1] == dp_q[0] && dn_q[1] == dn_q[0]) begin
            if ({1'b0, sample_cnt_q} == BIT_SAMPLES-1)
              sample_cnt_q <= 'd0;
            else
              sample_cnt_q <= sample_cnt_q + 1;
         end else begin // dp or dn at 1'bX too
            sample_cnt_q <= 'd0;
         end
      end
   end

   localparam       VALID_SAMPLES = BIT_SAMPLES/2; // consecutive valid samples

   reg [3:0]        nrzi_q;
   reg              se0_q;

   wire             sample_clk;

   assign sample_clk = ({1'b0, sample_cnt_q} == (VALID_SAMPLES-1)) ? 1'b1 : 1'b0;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         nrzi_q <= {SE0, SE0};
         se0_q <= 1'b0;
      end else begin
         if (sample_clk) begin
            nrzi_q <= {nrzi, nrzi_q[3:2]};
         end
         if (clk_gate_i) begin
            if (nrzi_q[1:0] == SE0 && nrzi_q[3:2] == SE0)
              se0_q <= 1'b1;
            else
              se0_q <= 1'b0;
         end
      end
   end

   localparam CNT_WIDTH = ceil_log2((2**14+1)*12);
   localparam [2:0] ST_RESET = 3'd0,
                    ST_DETACHED = 3'd1,
                    ST_ATTACHED = 3'd2,
                    ST_ENABLED = 3'd3,
                    ST_DETACH = 3'd4;

   reg [CNT_WIDTH-1:0] cnt_q, cnt_d;
   reg [2:0]           state_q, state_d;
   reg                 dp_pu_q, dp_pu_d;
   reg                 bus_reset_q, bus_reset_d;
   reg                 rx_en_q;

   assign dp_pu_o = dp_pu_q;
   assign bus_reset_o = bus_reset_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         cnt_q <= 'd0;
         state_q <= ST_RESET;
         dp_pu_q <= 1'b0;
         bus_reset_q <= 1'b0;
         rx_en_q <= 1'b0;
      end else begin
         if (clk_gate_i) begin
            cnt_q <= cnt_d;
            state_q <= state_d;
            dp_pu_q <= dp_pu_d;
            bus_reset_q <= bus_reset_d;
         end
         if (sample_clk) begin
            if (rx_en_i == 1'b1 && state_q == ST_ENABLED)
              rx_en_q <= 1'b1;
            else
              rx_en_q <= 1'b0;
         end
      end
   end
   
   always @(/*AS*/bus_reset_q or cnt_q or se0_q or state_q
            or usb_detach_i) begin
      cnt_d = 'd0;
      state_d = state_q;
      dp_pu_d = 1'b0;
      bus_reset_d = 1'b0;
      if (usb_detach_i == 1'b1 && state_q != ST_DETACH) begin
         state_d = ST_DETACH;
      end else begin
         case (state_q)
           ST_RESET : begin
              state_d = ST_DETACHED;
           end
           ST_DETACHED : begin
              cnt_d = cnt_q + 1;
              if (cnt_q[CNT_WIDTH-1 -:2] == 2'b11) // TSIGATT=16ms < 100ms (USB2.0 Tab.7-14 pag.188)
                state_d = ST_ATTACHED;
           end
           ST_ATTACHED : begin
              cnt_d = cnt_q + 1;
              dp_pu_d = 1'b1;
              if (cnt_q[CNT_WIDTH-1-8 -:2] == 2'b11) // 16ms + 64us
                state_d = ST_ENABLED;
           end
           ST_ENABLED : begin
              dp_pu_d = 1'b1;
              bus_reset_d = bus_reset_q & se0_q;
              if (se0_q) begin
                 cnt_d = cnt_q + 1;
                 if (cnt_q[5] == 1'b1) // 2.5us < TDETRST=2.67us < 10ms (USB2.0 Tab.7-14 pag.188)
                   bus_reset_d = 1'b1;
              end
           end
           ST_DETACH : begin
              bus_reset_d = 1'b1;
              if (~usb_detach_i)
                state_d = ST_DETACHED;
           end
           default : begin
              state_d = ST_RESET;
           end
         endcase
      end
   end

   localparam [2:0] ST_RX_IDLE = 3'd0,
                    ST_RX_SYNC = 3'd1,
                    ST_RX_DATA = 3'd2,
                    ST_RX_EOP = 3'd3,
                    ST_RX_ERR = 3'd4;

   reg [2:0]        rx_state_q, rx_state_d;
   reg [8:0]        shift_register_q, shift_register_d;
   reg [7:0]        rx_data_q, rx_data_d;
   reg [2:0]        stuffing_cnt_q, stuffing_cnt_d;

   assign rx_data_o = rx_data_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rx_state_q <= ST_RX_IDLE;
         shift_register_q <= 9'b100000000;
         rx_data_q <= 8'd0;
         stuffing_cnt_q <= 3'd0;
      end else begin
         if (sample_clk) begin
            rx_state_q <= rx_state_d;
            shift_register_q <= shift_register_d;
            rx_data_q <= rx_data_d;
            stuffing_cnt_q <= stuffing_cnt_d;
         end
      end
   end

   reg rx_valid;
   reg rx_err;
   reg rx_eop;

   always @(/*AS*/nrzi_q or rx_data_q or rx_en_q or rx_state_q
            or shift_register_q or stuffing_cnt_q) begin
      rx_state_d = rx_state_q;
      shift_register_d = 9'b100000000;
      rx_data_d = rx_data_q;
      stuffing_cnt_d = 3'd0;
      rx_valid = 1'b0;
      rx_err = 1'b0;
      rx_eop = 1'b0;

      if (~rx_en_q) begin
         rx_state_d = ST_RX_IDLE;
      end else begin
         case (rx_state_q)
           ST_RX_IDLE : begin
              if (nrzi_q[1:0] == DJ && nrzi_q[3:2] == DK) begin
                 rx_state_d = ST_RX_SYNC;
              end
           end
           ST_RX_SYNC : begin
              if ((nrzi_q[3:2] == SE1) || (nrzi_q[3:2] == SE0)) begin
                 rx_state_d = ST_RX_IDLE;
              end else begin
                 if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                    if (shift_register_q[8:3] == 6'b000000 && nrzi_q[3:2] == DK) begin
                       rx_state_d = ST_RX_DATA;
                       stuffing_cnt_d = stuffing_cnt_q + 1;
                    end else begin
                       rx_state_d = ST_RX_IDLE;
                    end
                 end else begin
                    shift_register_d = {1'b0, shift_register_q[8:1]};
                 end
              end
           end
           ST_RX_DATA : begin
              if (nrzi_q[3:2] == SE1) begin
                 rx_state_d = ST_RX_ERR;
              end else if (nrzi_q[3:2] == SE0) begin
                 // 1 or 2 SE0s for EOP: USB2.0 Tab.7-2 pag.145
                 // dribble bit: USB2.0 Fig.7-33 pag.158
                 if (shift_register_q == 9'b110000000) begin
                    rx_state_d = ST_RX_EOP;
                 end else if (shift_register_q[0] == 1'b1 && stuffing_cnt_q != 3'd6) begin
                    shift_register_d = 9'b110000000;
                    rx_data_d = shift_register_q[8:1];
                    rx_valid = 1'b1;
                 end else begin
                    rx_state_d = ST_RX_ERR;
                 end
              end else if (nrzi_q[1:0] == SE0) begin
                 rx_state_d = ST_RX_ERR;
              end else if (stuffing_cnt_q == 3'd6) begin
                 if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                    rx_state_d = ST_RX_ERR;
                 end else begin
                    shift_register_d = shift_register_q;
                 end
              end else begin
                 if (nrzi_q[1:0] == nrzi_q[3:2]) begin
                    shift_register_d[8] = 1'b1;
                    stuffing_cnt_d = stuffing_cnt_q + 1;
                 end else begin
                    shift_register_d[8] = 1'b0;
                 end
                 if (shift_register_q[0] == 1'b1) begin
                    shift_register_d[7:0] = 8'b10000000;
                    rx_data_d = shift_register_q[8:1];
                    rx_valid = 1'b1;
                 end else begin
                    shift_register_d[7:0] = shift_register_q[8:1];
                 end
              end
           end
           ST_RX_EOP : begin
              if (nrzi_q[3:2] == DJ) begin
                 rx_state_d = ST_RX_IDLE;
                 rx_eop = 1'b1;
              end else begin
                 rx_state_d = ST_RX_ERR;
              end
           end
           ST_RX_ERR : begin
              rx_state_d = ST_RX_IDLE;
              rx_err = 1'b1;
           end
           default : begin
              rx_state_d = ST_RX_ERR;
           end
         endcase
      end
   end

   reg rx_valid_q, rx_valid_qq;
   reg rx_err_q, rx_err_qq;
   reg rx_eop_q, rx_eop_qq;

   assign rx_ready_o = rx_valid_qq | rx_err_qq | rx_eop_qq;
   assign rx_valid_o = rx_valid_qq;
   assign rx_err_o = rx_err_qq;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rx_valid_q <= 1'b0;
         rx_err_q <= 1'b0;
         rx_eop_q <= 1'b0;
         rx_valid_qq <= 1'b0;
         rx_err_qq <= 1'b0;
         rx_eop_qq <= 1'b0;
      end else begin
         if (sample_clk) begin
            if (rx_valid)
              rx_valid_q <= 1'b1;
            if (rx_err)
              rx_err_q <= 1'b1;
            if (rx_eop)
              rx_eop_q <= 1'b1;
         end
         if (clk_gate_i) begin
            if ((rx_valid & sample_clk) | rx_valid_q) begin
               rx_valid_qq <= 1'b1;
               rx_valid_q <= 1'b0;
            end else begin
               rx_valid_qq <= 1'b0;
            end
            if ((rx_err & sample_clk) | rx_err_q) begin
               rx_err_qq <= 1'b1;
               rx_err_q <= 1'b0;
            end else begin
               rx_err_qq <= 1'b0;
            end
            if ((rx_eop & sample_clk) | rx_eop_q) begin
               rx_eop_qq <= 1'b1;
               rx_eop_q <= 1'b0;
            end else begin
               rx_eop_qq <= 1'b0;
            end
         end
      end
   end
endmodule
