//  USB 2.0 full speed Serial Interface Engine.
//  Written in verilog 2001

// SIE module shall manage physical and protocol layers of full
//   speed USB 2.0 (USB2.0 Chapters 7 and 8):
//   - Packet recognition, transaction sequencing.
//   - CRC generation and checking (Token and Data).
//   - Packet ID (PID) generation and checking/decoding.
//   And through PHY_RX and PHY_TX submodules:
//   - Start-Of-Packet (SOP) and Sync Pattern detection/generation.
//   - NRZI Data decoding/encoding.
//   - Bit Stuffing removal/insertion.
//   - End-Of-Packet (EOP) detection/generation.
//   - USB Reset detection.
//   - Serial-Parallel/Parallel-Serial conversion.

module sie
  #(parameter CTRL_MAXPACKETSIZE = 'd8,
    parameter IN_BULK_MAXPACKETSIZE = 'd8,
    parameter ENDP_CTRL = 4'd0,
    parameter ENDP_BULK = 4'd1,
    parameter BIT_SAMPLES = 'd4)
   (
    // ---- to/from USB_CDC module ------------------------------------
    output        usb_reset_o,
    // When dp_rx_i/dn_rx_i change and stay in SE0 condition for 2.5us, usb_reset_o shall be high.
    // When dp_rx_i/dn_rx_i change from SE0 condition, usb_reset_o shall return low
    //   after being high for at least 330ns.
    // When usb_detach_i is high and a usb detach has started, usb_reset_o shall be high.
    output [3:0]  endp_o,
    // endp_o shall be last recognized endpoint address and shall be
    //   updated at the end of next valid token packet.
    output [10:0] frame_o,
    // frame_o shall be last recognized frame number and shall be
    //   updated at the end of next valid Start-of-Frame token packet.
    input         clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input         rstn_i,
    // While rstn_i is low (active low), the module shall be reset.

    // ---- to/from OUT Endpoints ------------------------------------
    output [7:0]  out_data_o,
    output        out_valid_o,
    // While out_valid_o is high, the out_data_o shall be valid and both
    //   out_valid_o and out_data_o shall not change until consumed.
    output        out_err_o,
    // When both out_err_o and out_ready_o are high, SIE shall abort the
    //   current packet reception and OUT Endpoints shall manage the error
    //   condition.
    output        out_ready_o,
    // When both out_valid_o and out_ready_o are high, the out_data_o shall
    //   be consumed.
    // When setup_o is high and out_ready_o is high, a new SETUP transaction shall be
    //   received.
    // When setup_o, in_data_ack_o, out_valid_o and out_err_o are low and out_ready_o
    //   is high, the on-going OUT transaction shall end.
    // out_ready_o shall be high only for one clk_i period.
    input         out_nak_i,
    // When out_nak_i is high at the end of an OUT transaction, SIE shall send a NAK
    //   packet.

    // ---- to/from IN Endpoints -------------------------------------
    output        in_req_o,
    output        in_ready_o,
    // When both in_ready_o and in_valid_i are high, in_data_i or zero length
    //   packet shall be consumed.
    // When in_data_i or zlp is consumed, in_ready_o shall be high only for
    //   one clk_i period.
    output        in_data_ack_o,
    // When in_data_ack_o is high and out_ready_o is high, an ACK packet shall be received.
    input         in_valid_i,
    // While in_req_o is high and IN Endpoints have data or zero length packet
    //   available, IN Endpoints shall put in_valid_i high.
    input [7:0]   in_data_i,
    // While in_valid_i is high and in_zlp_i is low, in_data_i shall be valid.
    input         in_zlp_i,
    // While in_req_o is high and IN Endpoints have zero length packet available,
    //   IN Endpoints shall put both in_zlp_i and in_valid_i high.
    input         in_nak_i,
    // When in_nak_i is high at the start of an IN transaction, SIE shall send a NAK
    //   packet.

    // ---- to/from CONTROL Endpoint ---------------------------------
    output        setup_o,
    // While last correctly checked PID (USB2.0 8.3.1) is SETUP, setup_o shall
    //   be high, otherwise shall be low.
    input         usb_en_i,
    // While usb_en_i is low, the phy_rx module shall be disabled.
    input         usb_detach_i,
    // When usb_detach_i is high, a usb detach shall be requested.
    input [6:0]   addr_i,
    // addr_i shall be the device address.
    // addr_i shall be updated at the end of SET_ADDRESS control transfer.
    input         stall_i,
    // While control pipe is addressed and is in stall state, stall_i shall
    //   be high, otherwise shall be low.
    input         in_toggle_reset_i,
    // When in_toggle_reset_i is high, data toggle synchronization of
    //   IN bulk pipe shall be reset to DATA0.
    input         out_toggle_reset_i,
    // When out_toggle_reset_i is high, data toggle synchronization of
    //   OUT bulk pipe shall be reset to DATA0.

    // ---- to/from USB bus physical transmitters/receivers ----------
    output        dp_pu_o,
    // While dp_pu_o is high, a 1.5KOhm resistor shall pull-up dp line.
    // At power-on, dp_pu_o shall be low.
    // After TSIGATT time from power-on, dp_pu_o shall be high.
    output        tx_en_o,
    output        dp_tx_o,
    output        dn_tx_o,
    input         dp_rx_i,
    input         dn_rx_i
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   function [4:0] crc5;
      input [10:0] data;
      localparam [4:0] POLY5 = 5'b00101;
      reg [3:0]        i;
      begin
         crc5 = 5'b11111;
         for (i = 0; i <= 10; i = i + 1) begin
            if ((data[i] ^ crc5[4]) == 1'b1)
              crc5 = {crc5[3:0], 1'b0} ^ POLY5;
            else
              crc5 = {crc5[3:0], 1'b0};
         end
      end
   endfunction

   function [4:0] rev5;
      input [4:0] data;
      reg [2:0]   i;
      begin
         for (i = 0; i <= 4; i = i + 1) begin
            rev5[i] = data[4-i];
         end
      end
   endfunction

   function [15:0] crc16;
      input [7:0] data;
      input [15:0] crc;
      localparam [15:0] POLY16 = 16'h8005;
      reg [3:0]         i;
      begin
         crc16 = crc;
         for (i = 0; i <= 7; i = i + 1) begin
            if ((data[i[2:0]] ^ crc16[15]) == 1'b1)
              crc16 = {crc16[14:0], 1'b0} ^ POLY16;
            else
              crc16 = {crc16[14:0], 1'b0};
         end
      end
   endfunction

   function [7:0] rev8;
      input [7:0] data;
      reg [3:0]   i;
      begin
         for (i = 0; i <= 7; i = i + 1) begin
            rev8[i[2:0]] = data[7-i];
         end
      end
   endfunction

   localparam [15:0] RESI16 = 16'h800D; // = rev16(~16'h4FFE)
   localparam [3:0]  PHY_IDLE = 4'd0,
                     PHY_RX_PID = 4'd1,
                     PHY_RX_ADDR = 4'd2,
                     PHY_RX_ENDP = 4'd3,
                     PHY_RX_DATA0 = 4'd4,
                     PHY_RX_DATA = 4'd5,
                     PHY_RX_WAIT_EOP = 4'd6,
                     PHY_TX_HANDSHAKE_PID = 4'd7,
                     PHY_TX_DATA_PID = 4'd8,
                     PHY_TX_DATA = 4'd9,
                     PHY_TX_CRC16_0 = 4'd10,
                     PHY_TX_CRC16_1 = 4'd11;
   localparam [3:0]  PID_RESERVED = 4'b0000,
                     PID_OUT = 4'b0001,
                     PID_IN = 4'b1001,
                     PID_SOF = 4'b0101,
                     PID_SETUP = 4'b1101,
                     PID_DATA0 = 4'b0011,
                     PID_DATA1 = 4'b1011,
                     PID_ACK = 4'b0010,
                     PID_NAK = 4'b1010,
                     PID_STALL = 4'b1110;
   localparam        IN_WIDTH = (IN_BULK_MAXPACKETSIZE > CTRL_MAXPACKETSIZE) ?
                     ceil_log2(IN_BULK_MAXPACKETSIZE+1) : ceil_log2(CTRL_MAXPACKETSIZE+1);

   reg [3:0]         phy_state_q, phy_state_d;
   reg [3:0]         pid_q, pid_d;
   reg [6:0]         addr_q, addr_d;
   reg [3:0]         endp_q, endp_d;
   reg [10:0]        frame_q, frame_d;
   reg [15:0]        data_q, data_d;
   reg [15:0]        crc16_q, crc16_d;
   reg [15:0]        datain_toggle_q, datain_toggle_d;
   reg [15:0]        dataout_toggle_q, dataout_toggle_d;
   reg [IN_WIDTH-1:0] in_byte_q, in_byte_d;
   reg                out_valid;
   reg                out_err;
   reg                out_eop;
   reg                in_data_ack;
   reg [7:0]          tx_data;
   reg                tx_valid;
   reg                in_ready;
   reg                in_req;
   reg [ceil_log2(8*BIT_SAMPLES)-1:0] delay_cnt_q;
   reg                                out_err_q;
   reg                                out_eop_q;
   reg                                in_data_ack_q;

   wire [7:0]                         rx_data;
   wire                               rx_valid;
   wire                               rx_err;
   wire                               usb_reset;
   wire                               rstn;
   wire                               clk_gate;
   wire                               rx_ready;
   wire                               tx_ready;
   wire                               delay_end;

   assign usb_reset_o = usb_reset;
   assign endp_o = endp_q;
   assign frame_o = frame_q;
   assign out_data_o = data_q[15:8];
   assign out_valid_o = out_valid;
   assign out_err_o = out_err_q;
   assign in_req_o = in_req;
   assign setup_o = (pid_q == PID_SETUP) ? 1'b1 : 1'b0;
   assign in_data_ack_o = in_data_ack_q;
   assign delay_end = ((delay_cnt_q == 8*BIT_SAMPLES-1) ? 1'b1 : 1'b0);
   assign out_ready_o = (rx_ready & out_valid) |
                        (delay_end & (out_err_q | out_eop_q));
   assign in_ready_o = tx_ready & in_ready;

   assign rstn = rstn_i & ~usb_reset;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         delay_cnt_q <= 'd0;
         out_err_q <= 1'b0;
         out_eop_q <= 1'b0;
         in_data_ack_q <= 1'b0;
      end else begin
         if (phy_state_q == PHY_RX_PID || phy_state_q == PHY_RX_ENDP ||
             phy_state_q == PHY_RX_DATA) begin
            delay_cnt_q <= 'd0;
            if (phy_state_q == PHY_RX_DATA)
              out_err_q <= out_err | out_err_q;
            out_eop_q <= out_eop | out_eop_q;
            in_data_ack_q <= in_data_ack | in_data_ack_q;
         end else if (!delay_end) begin
            delay_cnt_q <= delay_cnt_q + 1;
         end else begin
            out_err_q <= 1'b0;
            out_eop_q <= 1'b0;
            in_data_ack_q <= 1'b0;
         end
      end
   end

   assign clk_gate = rx_ready | tx_ready;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         phy_state_q <= PHY_IDLE;
         pid_q <= PID_RESERVED;
         addr_q <= 7'd0;
         endp_q <= ENDP_CTRL;
         frame_q <= 11'd0;
         data_q <= 16'd0;
         crc16_q <= 16'd0;
         datain_toggle_q <= 16'd0;
         dataout_toggle_q <= 16'd0;
         in_byte_q <= 'd0;
      end else begin
         if (clk_gate) begin
            phy_state_q <= phy_state_d;
            pid_q <= pid_d;
            addr_q <= addr_d;
            endp_q <= endp_d;
            frame_q <= frame_d;
            data_q <= data_d;
            crc16_q <= crc16_d;
            datain_toggle_q <= 16'd0;
            datain_toggle_q[ENDP_CTRL] <= datain_toggle_d[ENDP_CTRL];
            datain_toggle_q[ENDP_BULK] <= datain_toggle_d[ENDP_BULK];
            dataout_toggle_q <= 16'd0;
            dataout_toggle_q[ENDP_CTRL] <= dataout_toggle_d[ENDP_CTRL];
            dataout_toggle_q[ENDP_BULK] <= dataout_toggle_d[ENDP_BULK];
            in_byte_q <= in_byte_d;
         end
      end
   end

   always @(/*AS*/addr_i or addr_q or crc16_q or data_q
            or datain_toggle_q or dataout_toggle_q or endp_q
            or frame_q or in_byte_q or in_data_i or in_nak_i
            or in_toggle_reset_i or in_valid_i or in_zlp_i
            or out_nak_i or out_toggle_reset_i or phy_state_q or pid_q
            or rx_data or rx_err or rx_valid or stall_i) begin
      phy_state_d = phy_state_q;
      pid_d = pid_q;
      addr_d = addr_q;
      endp_d = endp_q;
      frame_d = frame_q;
      data_d = {8'd0, rx_data};
      crc16_d = crc16_q;
      datain_toggle_d = datain_toggle_q;
      dataout_toggle_d = dataout_toggle_q;
      in_byte_d = in_byte_q;
      out_valid = 1'b0;
      out_err = 1'b0;
      out_eop = 1'b0;
      in_data_ack = 1'b0;
      tx_data = 8'd0;
      tx_valid = 1'b0;
      in_ready = 1'b0;
      in_req = 1'b0;

      if (in_toggle_reset_i == 1'b1)
        datain_toggle_d[ENDP_BULK] = 1'b0;
      if (out_toggle_reset_i == 1'b1)
        dataout_toggle_d[ENDP_BULK] = 1'b0;

      if (rx_err == 1'b1) begin
         phy_state_d = PHY_IDLE;
         out_err = 1'b1;
      end else begin
         case (phy_state_q)
           PHY_RX_WAIT_EOP : begin
              if (rx_valid == 1'b0) begin
                 phy_state_d = PHY_IDLE;
              end
           end
           PHY_IDLE : begin
              if (rx_valid == 1'b1) begin
                 phy_state_d = PHY_RX_PID;
              end
           end
           PHY_RX_PID : begin
              pid_d = PID_RESERVED;
              if (data_q[7:4] == ~data_q[3:0]) begin
                 pid_d = data_q[3:0];
                 case (data_q[1:0])
                   2'b01 : begin // Token
                      if (rx_valid == 1'b1) begin
                         phy_state_d = PHY_RX_ADDR;
                      end else begin
                         phy_state_d = PHY_IDLE;
                      end
                   end
                   2'b11 : begin // Data
                      if (rx_valid == 1'b1) begin
                         if ((data_q[3:2] == PID_DATA0[3:2] || data_q[3:2] == PID_DATA1[3:2]) &&
                             (pid_q == PID_SETUP || pid_q == PID_OUT) && addr_q == addr_i) begin
                            phy_state_d = PHY_RX_DATA0;
                         end else begin
                            phy_state_d = PHY_RX_WAIT_EOP;
                         end
                      end else begin
                         phy_state_d = PHY_IDLE;
                      end
                   end
                   2'b10 : begin // Handshake
                      if (rx_valid == 1'b0) begin
                         phy_state_d = PHY_IDLE;
                         if (data_q[3:2] == PID_ACK[3:2] && addr_q == addr_i) begin // ACK
                            datain_toggle_d[endp_q] = ~datain_toggle_q[endp_q];
                            out_eop = 1'b1;
                            in_data_ack = 1'b1;
                         end
                      end else begin
                         phy_state_d = PHY_RX_WAIT_EOP;
                      end
                   end
                   default : begin // Special -> Not valid
                      if (rx_valid == 1'b0) begin
                         phy_state_d = PHY_IDLE;
                      end else begin
                         phy_state_d = PHY_RX_WAIT_EOP;
                      end
                   end
                 endcase
              end else if (rx_valid == 1'b1) begin
                 phy_state_d = PHY_RX_WAIT_EOP;
              end else begin
                 phy_state_d = PHY_IDLE;
              end
              crc16_d = 16'hFFFF;
           end
           PHY_RX_ADDR : begin
              if (rx_valid == 1'b1) begin
                 phy_state_d = PHY_RX_ENDP;
              end else begin
                 phy_state_d = PHY_IDLE;
              end
              data_d[15:8] = data_q[7:0];
           end
           PHY_RX_ENDP : begin
              if (rx_valid == 1'b0) begin
                 phy_state_d = PHY_IDLE;
                 if (crc5({data_q[2:0], data_q[15:8]}) == rev5(~data_q[7:3])) begin
                    if (pid_q == PID_SOF) begin
                       frame_d = {data_q[2:0], data_q[15:8]};
                    end else begin
                       addr_d = data_q[14:8];
                       endp_d = {data_q[2:0], data_q[15]};
                       if (data_q[14:8] == addr_i) begin
                          if (pid_q == PID_IN) begin
                             phy_state_d = PHY_TX_DATA_PID;
                          end else if (pid_q == PID_SETUP) begin
                             datain_toggle_d[ENDP_CTRL] = 1'b1;
                             dataout_toggle_d[ENDP_CTRL] = 1'b0;
                             out_eop = 1'b1; // will be delayed for ctrl_enpd to capture new endp_q
                          end
                       end
                    end
                 end
              end else begin
                 phy_state_d = PHY_RX_WAIT_EOP;
              end
           end
           PHY_RX_DATA0 : begin
              if (rx_valid == 1'b1) begin
                 phy_state_d = PHY_RX_DATA;
              end else begin
                 phy_state_d = PHY_IDLE;
              end
              data_d[15:8] = data_q[7:0];
              crc16_d = crc16(data_q[7:0], crc16_q);
           end
           PHY_RX_DATA : begin
              if (rx_valid == 1'b1) begin
                 out_valid = 1'b1;
              end else begin
                 if (crc16(data_q[7:0], crc16_q) == RESI16) begin
                    if (dataout_toggle_q[endp_q] == pid_q[3] &&
                        (endp_q == ENDP_CTRL || endp_q == ENDP_BULK)) begin
                       dataout_toggle_d[endp_q] = ~dataout_toggle_q[endp_q];
                       out_eop = 1'b1;
                    end else begin
                       out_err = 1'b1;
                    end
                    phy_state_d = PHY_TX_HANDSHAKE_PID;
                    if (stall_i == 1'b1) begin
                       pid_d = PID_STALL;
                    end else if (out_nak_i == 1'b1) begin
                       dataout_toggle_d[endp_q] = dataout_toggle_q[endp_q];
                       pid_d = PID_NAK;
                    end else begin
                       pid_d = PID_ACK;
                    end
                 end else begin
                    out_err = 1'b1;
                    phy_state_d = PHY_IDLE;
                 end
              end
              data_d[15:8] = data_q[7:0];
              crc16_d = crc16(data_q[7:0], crc16_q);
           end
           PHY_TX_HANDSHAKE_PID : begin
              tx_data = {~pid_q, pid_q};
              phy_state_d = PHY_IDLE;
              tx_valid = 1'b1;
           end
           PHY_TX_DATA_PID : begin
              if (stall_i == 1'b1) begin
                 pid_d = PID_STALL;
                 tx_data = {~PID_STALL, PID_STALL};
                 phy_state_d = PHY_IDLE;
              end else if ((endp_q != ENDP_CTRL && endp_q != ENDP_BULK) ||
                           (in_nak_i == 1'b1) ||
                           (in_valid_i == 1'b0 &&
                            ((endp_q == ENDP_BULK && in_byte_q != IN_BULK_MAXPACKETSIZE[IN_WIDTH-1:0]) ||
                             (endp_q == ENDP_CTRL && in_byte_q != CTRL_MAXPACKETSIZE[IN_WIDTH-1:0])))) begin
                 pid_d = PID_NAK;
                 tx_data = {~PID_NAK, PID_NAK};
                 phy_state_d = PHY_IDLE;
              end else begin
                 if (datain_toggle_q[endp_q] == 1'b0) begin
                    pid_d = PID_DATA0;
                    tx_data = {~PID_DATA0, PID_DATA0};
                 end else begin
                    pid_d = PID_DATA1;
                    tx_data = {~PID_DATA1, PID_DATA1};
                 end
                 if ((in_valid_i == 1'b0) || (in_zlp_i == 1'b1)) begin
                    phy_state_d = PHY_TX_CRC16_0;
                 end else begin
                    in_ready = 1'b1;
                    phy_state_d = PHY_TX_DATA;
                 end
              end
              data_d[7:0] = in_data_i;
              crc16_d = 16'hFFFF;
              in_byte_d = 'd0;
              tx_valid = 1'b1;
              in_req = 1'b1;
           end
           PHY_TX_DATA : begin
              tx_data = data_q[7:0];
              if (in_valid_i == 1'b0 ||
                  (endp_q == ENDP_BULK && in_byte_q == IN_BULK_MAXPACKETSIZE[IN_WIDTH-1:0]-1) ||
                  (endp_q == ENDP_CTRL && in_byte_q == CTRL_MAXPACKETSIZE[IN_WIDTH-1:0]-1)) begin
                 phy_state_d = PHY_TX_CRC16_0;
              end else begin
                 in_ready = 1'b1;
              end
              data_d[7:0] = in_data_i;
              crc16_d = crc16(data_q[7:0], crc16_q);
              tx_valid = 1'b1;
              in_byte_d = in_byte_q + 1;
              in_req = 1'b1;
           end
           PHY_TX_CRC16_0 : begin
              tx_data = rev8(~crc16_q[15:8]);
              phy_state_d = PHY_TX_CRC16_1;
              tx_valid = 1'b1;
           end
           PHY_TX_CRC16_1 : begin
              tx_data = rev8(~crc16_q[7:0]);
              phy_state_d = PHY_IDLE;
              tx_valid = 1'b1;
           end
           default : begin
              phy_state_d = PHY_IDLE;
           end
         endcase
      end
   end

   wire tx_en;
   wire rx_en;

   assign tx_en_o = tx_en;
   assign rx_en = ~tx_en & usb_en_i;

   phy_rx #(.BIT_SAMPLES(BIT_SAMPLES))
   u_phy_rx (.rx_data_o(rx_data),
             .rx_valid_o(rx_valid),
             .rx_err_o(rx_err),
             .dp_pu_o(dp_pu_o),
             .usb_reset_o(usb_reset),
             .rx_ready_o(rx_ready),
             .clk_i(clk_i),
             .rstn_i(rstn_i),
             .rx_en_i(rx_en),
             .usb_detach_i(usb_detach_i),
             .dp_rx_i(dp_rx_i),
             .dn_rx_i(dn_rx_i));

   phy_tx #(.BIT_SAMPLES(BIT_SAMPLES))
   u_phy_tx (.tx_en_o(tx_en),
             .dp_tx_o(dp_tx_o),
             .dn_tx_o(dn_tx_o),
             .tx_ready_o(tx_ready),
             .clk_i(clk_i),
             .rstn_i(rstn),
             .tx_valid_i(tx_valid),
             .tx_data_i(tx_data));
endmodule
