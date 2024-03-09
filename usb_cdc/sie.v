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
//   - Bus Reset detection.
//   - Serial-Parallel/Parallel-Serial conversion.
//   - 1.5kOhm pull-up resistor on dp line management.

`define max(a,b) ((a) > (b) ? (a) : (b))

module sie
  #(parameter IN_CTRL_MAXPACKETSIZE = 'd8,
    parameter IN_BULK_MAXPACKETSIZE = 'd8,  // 8, 16, 32, 64
    parameter IN_INT_MAXPACKETSIZE = 'd8,  // <= 64
    parameter IN_ISO_MAXPACKETSIZE = 'd8,  // <= 1023
    parameter BIT_SAMPLES = 'd4)
   (
    // ---- to/from USB_CDC module ------------------------------------
    output [10:0] frame_o,
    // frame_o shall be last recognized frame number and shall be
    //   updated at the end of next valid Start-of-Frame token packet.
    // When clk_gate_i is high, frame_o shall be updated.
    input         clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input         rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    input         clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.

    // ---- to/from IN/OUT Endpoints ------------------------------------
    output        bus_reset_o,
    // When dp_rx_i/dn_rx_i change and stay in SE0 condition for 2.5us, bus_reset_o shall be high.
    // When dp_rx_i/dn_rx_i change from SE0 condition, bus_reset_o shall return low.
    // While usb_detach_i is high and a usb detach has started, bus_reset_o shall be high.
    // When clk_gate_i is high, bus_reset_o shall be updated.
    output [3:0]  endp_o,
    // endp_o shall be last recognized endpoint address and shall be
    //   updated at the end of next valid token packet.
    // When clk_gate_i is high, endp_o shall be updated.
    input         stall_i,
    // While a bulk, interrupt or control pipe is addressed and is in
    //   stall state, stall_i shall be high, otherwise shall be low.
    // When clk_gate_i is high, stall_i shall be updated.

    // ---- to/from OUT Endpoints ------------------------------------
    output [7:0]  out_data_o,
    output        out_valid_o,
    // While out_valid_o is high, the out_data_o shall be valid and both
    //   out_valid_o and out_data_o shall not change until consumed.
    // When clk_gate_i is high, out_valid_o shall be updated.
    output        out_err_o,
    // When both out_err_o and out_ready_o are high, SIE shall abort the
    //   current packet reception and OUT Endpoints shall manage the error
    //   condition.
    // When clk_gate_i is high, out_err_o shall be updated.
    output        setup_o,
    // While last correctly checked PID (USB2.0 8.3.1) is SETUP, setup_o shall
    //   be high, otherwise shall be low.
    // When clk_gate_i is high, setup_o shall be updated.
    output        out_ready_o,
    // When both out_valid_o and out_ready_o are high, the out_data_o shall
    //   be consumed.
    // When setup_o is high and out_ready_o is high, a new SETUP transaction shall be
    //   received.
    // When setup_o, out_valid_o and out_err_o are low and out_ready_o is high, the
    //   on-going OUT packet shall end (EOP).
    // out_ready_o shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, out_ready_o shall be updated.
    input         out_nak_i,
    // When out_nak_i is high at the end of an OUT packet, SIE shall send a NAK
    //   packet.
    // When clk_gate_i is high, out_nak_i shall be updated.

    // ---- to/from IN Endpoints -------------------------------------
    output        in_req_o,
    // When both in_req_o and in_ready_o are high, a new IN packet shall be requested.
    // When clk_gate_i is high, in_req_o shall be updated.
    output        in_ready_o,
    // When both in_ready_o and in_valid_i are high, in_data_i or zero length
    //   packet shall be consumed.
    // When in_data_i or zlp is consumed, in_ready_o shall be high only for
    //   one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, in_ready_o shall be updated.
    output        in_data_ack_o,
    // When in_data_ack_o is high and out_ready_o is high, an ACK packet shall be received.
    // When clk_gate_i is high, in_data_ack_o shall be updated.
    input         in_valid_i,
    // While IN Endpoints have data or zero length packet available, IN Endpoints
    //   shall put in_valid_i high.
    // When clk_gate_i is high, in_valid_i shall be updated.
    input [7:0]   in_data_i,
    // While in_valid_i is high and in_zlp_i is low, in_data_i shall be valid.
    input         in_zlp_i,
    // While IN Endpoints have zero length packet available, IN Endpoints
    //   shall put both in_zlp_i and in_valid_i high.
    // When clk_gate_i is high, in_zlp_i shall be updated.
    input         in_nak_i,
    // When in_nak_i is high at the start of an IN packet, SIE shall send a NAK
    //   packet.
    // When clk_gate_i is high, in_nak_i shall be updated.

    // ---- to/from CONTROL Endpoint ---------------------------------
    input         usb_en_i,
    // While usb_en_i is low, the phy_rx module shall be disabled.
    // When clk_gate_i is high, usb_en_i shall be updated.
    input         usb_detach_i,
    // When usb_detach_i is high, a usb detach shall be requested.
    // When clk_gate_i is high, usb_detach_i shall be updated.
    input [6:0]   addr_i,
    // addr_i shall be the device address.
    // addr_i shall be updated at the end of SET_ADDRESS control transfer.
    // When clk_gate_i is high, addr_i shall be updated.
    input [15:0]  in_bulk_endps_i,
    // While in_bulk_endps_i[i] is high, endp=i shall be enabled as IN bulk endpoint.
    //   endp=0 is reserved for IN control endpoint.
    // When clk_gate_i is high, in_bulk_endps_i shall be updated.
    input [15:0]  out_bulk_endps_i,
    // While out_bulk_endps_i[i] is high, endp=i shall be enabled as OUT bulk endpoint
    //   endp=0 is reserved for OUT control endpoint.
    // When clk_gate_i is high, out_bulk_endps_i shall be updated.
    input [15:0]  in_int_endps_i,
    // While in_int_endps_i[i] is high, endp=i shall be enabled as IN interrupt endpoint.
    //   endp=0 is reserved for IN control endpoint.
    // When clk_gate_i is high, in_int_endps_i shall be updated.
    input [15:0]  out_int_endps_i,
    // While out_int_endps_i[i] is high, endp=i shall be enabled as OUT interrupt endpoint
    //   endp=0 is reserved for OUT control endpoint.
    // When clk_gate_i is high, out_int_endps_i shall be updated.
    input [15:0]  in_iso_endps_i,
    // While in_iso_endps_i[i] is high, endp=i shall be enabled as IN isochronous endpoint.
    //   endp=0 is reserved for IN control endpoint.
    // When clk_gate_i is high, in_iso_endps_i shall be updated.
    input [15:0]  out_iso_endps_i,
    // While out_iso_endps_i[i] is high, endp=i shall be enabled as OUT isochronous endpoint
    //   endp=0 is reserved for OUT control endpoint.
    // When clk_gate_i is high, out_iso_endps_i shall be updated.
    input [15:0]  in_toggle_reset_i,
    // When in_toggle_reset_i[i] is high, data toggle synchronization of
    //   IN bulk/int pipe at endpoint=i shall be reset to DATA0.
    // When clk_gate_i is high, in_toggle_reset_i shall be updated.
    input [15:0]  out_toggle_reset_i,
    // When out_toggle_reset_i[i] is high, data toggle synchronization of
    //   OUT bulk/int pipe at endpoint=i shall be reset to DATA0.
    // When clk_gate_i is high, out_toggle_reset_i shall be updated.

    // ---- to/from USB bus physical transmitters/receivers ----------
    output        dp_pu_o,
    // While dp_pu_o is high, a 1.5KOhm resistor shall pull-up the dp line.
    // At power-on or when usb_detach_i is high, dp_pu_o shall be low.
    // After TSIGATT time from power-on or from usb_detach_i change to low, dp_pu_o shall be high.
    output        tx_en_o,
    output        dp_tx_o,
    output        dn_tx_o,
    input         dp_rx_i,
    input         dn_rx_i
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

   function [4:0] crc5;
      input [10:0] data;
      localparam [4:0] POLY5 = 5'b00101;
      integer          i;
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
      integer     i;
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
      integer           i;
      begin
         crc16 = crc;
         for (i = 0; i <= 7; i = i + 1) begin
            if ((data[i] ^ crc16[15]) == 1'b1)
              crc16 = {crc16[14:0], 1'b0} ^ POLY16;
            else
              crc16 = {crc16[14:0], 1'b0};
         end
      end
   endfunction

   function [7:0] rev8;
      input [7:0] data;
      integer     i;
      begin
         for (i = 0; i <= 7; i = i + 1) begin
            rev8[i] = data[7-i];
         end
      end
   endfunction

   localparam [15:0] RESI16 = 16'h800D; // = rev16(~16'h4FFE)
   localparam [3:0]  ENDP_CTRL = 'd0;
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
   localparam        IN_WIDTH = ceil_log2(1+`max(IN_CTRL_MAXPACKETSIZE,
                                                 `max(IN_BULK_MAXPACKETSIZE,
                                                      `max(IN_INT_MAXPACKETSIZE, IN_ISO_MAXPACKETSIZE))));

   reg [3:0]         phy_state_q, phy_state_d;
   reg [3:0]         pid_q, pid_d;
   reg [6:0]         addr_q, addr_d;
   reg [3:0]         endp_q, endp_d;
   reg [10:0]        frame_q, frame_d;
   reg [15:0]        data_q, data_d;
   reg [15:0]        crc16_q, crc16_d;
   reg [15:0]        in_toggle_q, in_toggle_d;
   reg [15:0]        out_toggle_q, out_toggle_d;
   reg [15:0]        in_zlp_q, in_zlp_d;
   reg [IN_WIDTH-1:0] in_byte_q, in_byte_d;
   reg                out_valid;
   reg                out_err;
   reg                out_eop;
   reg                in_data_ack;
   reg [7:0]          tx_data;
   reg                tx_valid;
   reg                in_ready;
   reg                in_req;
   reg [ceil_log2(8)-1:0] delay_cnt_q;
   reg                    out_err_q;
   reg                    out_eop_q;
   reg                    in_req_q;
   reg                    in_data_ack_q;

   wire [7:0]             rx_data;
   wire                   rx_valid;
   wire                   rx_err;
   wire                   bus_reset;
   wire                   rstn;
   wire                   rx_ready;
   wire                   tx_ready;
   wire                   delay_end;
   wire [15:0]            in_toggle_endps;
   wire [15:0]            out_toggle_endps;
   wire [15:0]            in_valid_endps;
   wire [15:0]            out_valid_endps;

   assign bus_reset_o = bus_reset;
   assign endp_o = endp_q;
   assign frame_o = frame_q;
   assign out_data_o = data_q[15:8];
   assign out_valid_o = out_valid;
   assign out_err_o = out_err_q;
   assign in_req_o = in_req_q;
   assign setup_o = (pid_q == PID_SETUP) ? 1'b1 : 1'b0;
   assign in_data_ack_o = in_data_ack_q;
   assign delay_end = (({1'b0, delay_cnt_q} == (8-1)) ? 1'b1 : 1'b0);
   assign out_ready_o = (rx_ready & out_valid) |
                        (delay_end & (out_err_q | out_eop_q));
   assign in_ready_o = (tx_ready & in_ready) | in_data_ack_q | in_req_q;

   assign rstn = rstn_i & ~bus_reset;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         delay_cnt_q <= 'd0;
         out_err_q <= 1'b0;
         out_eop_q <= 1'b0;
         in_req_q <= 1'b0;
         in_data_ack_q <= 1'b0;
      end else begin
         if (clk_gate_i) begin
            in_req_q <= in_req & rx_ready;
            in_data_ack_q <= in_data_ack & (rx_ready | tx_ready);
            if (phy_state_q == PHY_RX_PID || phy_state_q == PHY_RX_ENDP ||
                phy_state_q == PHY_RX_DATA) begin
               delay_cnt_q <= 'd0;
               if (rx_ready) begin
                  if (phy_state_q == PHY_RX_DATA)
                    out_err_q <= out_err | out_err_q;
                  out_eop_q <= out_eop | out_eop_q;
               end
            end else if (!delay_end) begin
               delay_cnt_q <= delay_cnt_q + 1;
            end else begin
               out_err_q <= 1'b0;
               out_eop_q <= 1'b0;
            end
         end
      end
   end

   localparam [15:0] CTRL_ENDPS = 16'h01;

   assign in_toggle_endps = in_bulk_endps_i|in_int_endps_i|CTRL_ENDPS;
   assign out_toggle_endps = out_bulk_endps_i|out_int_endps_i|CTRL_ENDPS;
   assign in_valid_endps = in_bulk_endps_i|in_int_endps_i|in_iso_endps_i|CTRL_ENDPS;
   assign out_valid_endps = out_bulk_endps_i|out_int_endps_i|out_iso_endps_i|CTRL_ENDPS;

   integer i;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         phy_state_q <= PHY_IDLE;
         pid_q <= PID_RESERVED;
         addr_q <= 7'd0;
         endp_q <= ENDP_CTRL;
         frame_q <= 11'd0;
         data_q <= 16'd0;
         crc16_q <= 16'd0;
         in_toggle_q <= 16'd0;
         out_toggle_q <= 16'd0;
         in_zlp_q <= 16'd0;
         in_byte_q <= 'd0;
      end else begin
         if (clk_gate_i) begin
            if (rx_ready | tx_ready) begin
               phy_state_q <= phy_state_d;
               pid_q <= pid_d;
               addr_q <= addr_d;
               endp_q <= endp_d;
               frame_q <= frame_d;
               data_q <= data_d;
               crc16_q <= crc16_d;
               in_toggle_q <= in_toggle_d & in_toggle_endps;
               out_toggle_q <= out_toggle_d & out_toggle_endps;
               in_zlp_q <= in_zlp_d & in_valid_endps;
               in_byte_q <= in_byte_d;
            end
            for (i = 0; i < 16; i = i + 1) begin
               if (in_toggle_reset_i[i] & in_toggle_endps[i] & ~CTRL_ENDPS[i])
                 in_toggle_q[i] <= 1'b0;
               if (out_toggle_reset_i[i] & out_toggle_endps[i] & ~CTRL_ENDPS[i])
                 out_toggle_q[i] <= 1'b0;
            end
         end
      end
   end

   always @(/*AS*/addr_i or addr_q or crc16_q or data_q or endp_q
            or frame_q or in_bulk_endps_i or in_byte_q or in_data_i
            or in_int_endps_i or in_iso_endps_i or in_nak_i
            or in_toggle_endps or in_toggle_q or in_valid_endps
            or in_valid_i or in_zlp_i or in_zlp_q or out_iso_endps_i
            or out_nak_i or out_toggle_endps or out_toggle_q
            or out_valid_endps or phy_state_q or pid_q or rx_data
            or rx_err or rx_valid or stall_i) begin
      phy_state_d = phy_state_q;
      pid_d = pid_q;
      addr_d = addr_q;
      endp_d = endp_q;
      frame_d = frame_q;
      data_d = {8'd0, rx_data};
      crc16_d = crc16_q;
      in_toggle_d = in_toggle_q;
      out_toggle_d = out_toggle_q;
      in_zlp_d = in_zlp_q;
      in_byte_d = 'd0;
      out_valid = 1'b0;
      out_err = 1'b0;
      out_eop = 1'b0;
      in_data_ack = 1'b0;
      tx_data = 8'd0;
      tx_valid = 1'b0;
      in_ready = 1'b0;
      in_req = 1'b0;

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
                             (pid_q == PID_SETUP || pid_q == PID_OUT) &&
                             addr_q == addr_i && out_valid_endps[endp_q] == 1'b1) begin
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
                         if (data_q[3:2] == PID_ACK[3:2] && addr_q == addr_i &&
                             in_toggle_endps[endp_q] == 1'b1) begin // ACK
                            in_toggle_d[endp_q] = ~in_toggle_q[endp_q];
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
              addr_d[0] = ~addr_i[0];  // to invalid addr_q in case of token error
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
                             in_req = 1'b1;
                          end else if (pid_q == PID_SETUP) begin
                             in_toggle_d[ENDP_CTRL] = 1'b1;
                             out_toggle_d[ENDP_CTRL] = 1'b0;
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
                    if ((out_toggle_q[endp_q] == pid_q[3] && out_toggle_endps[endp_q] == 1'b1) ||
                        out_iso_endps_i[endp_q] == 1'b1) begin
                       out_toggle_d[endp_q] = ~out_toggle_q[endp_q];
                       out_eop = 1'b1;
                    end else begin
                       out_err = 1'b1;
                    end
                    if (out_toggle_endps[endp_q] == 1'b1)
                      phy_state_d = PHY_TX_HANDSHAKE_PID;
                    else
                      phy_state_d = PHY_IDLE;
                    if (stall_i == 1'b1) begin
                       pid_d = PID_STALL;
                    end else if (out_nak_i == 1'b1) begin
                       out_toggle_d[endp_q] = out_toggle_q[endp_q];
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
              tx_valid = 1'b1;
              if (in_valid_endps[endp_q] == 1'b0) begin // USB2.0 8.3.2 pag.197)
                 tx_valid = 1'b0;
                 phy_state_d = PHY_IDLE;
              end else if (stall_i == 1'b1) begin
                 if (in_toggle_endps[endp_q] == 1'b1) begin
                    pid_d = PID_STALL;
                    tx_data = {~PID_STALL, PID_STALL};
                 end else begin
                    tx_valid = 1'b0;
                 end
                 phy_state_d = PHY_IDLE;
              end else if ((in_nak_i == 1'b1) || (in_valid_i == 1'b0 && in_zlp_q[endp_q] == 1'b0)) begin
                 if (in_toggle_endps[endp_q] == 1'b1) begin
                    pid_d = PID_NAK;
                    tx_data = {~PID_NAK, PID_NAK};
                 end else begin
                    tx_valid = 1'b0;
                 end
                 phy_state_d = PHY_IDLE;
              end else begin
                 if (in_toggle_q[endp_q] == 1'b0) begin
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
              in_zlp_d[endp_q] = 1'b0;
           end
           PHY_TX_DATA : begin
              tx_data = data_q[7:0];
              if ((endp_q == ENDP_CTRL && in_byte_q == IN_CTRL_MAXPACKETSIZE[IN_WIDTH-1:0]-1) ||
                  (in_bulk_endps_i[endp_q] == 1'b1 && in_byte_q == IN_BULK_MAXPACKETSIZE[IN_WIDTH-1:0]-1) ||
                  (in_int_endps_i[endp_q] == 1'b1 && in_byte_q == IN_INT_MAXPACKETSIZE[IN_WIDTH-1:0]-1) ||
                  (in_iso_endps_i[endp_q] == 1'b1 && in_byte_q == IN_ISO_MAXPACKETSIZE[IN_WIDTH-1:0]-1)) begin
                 phy_state_d = PHY_TX_CRC16_0;
                 in_zlp_d[endp_q] = 1'b1;
              end else if (in_valid_i == 1'b0) begin
                 phy_state_d = PHY_TX_CRC16_0;
              end else begin
                 in_ready = 1'b1;
              end
              data_d[7:0] = in_data_i;
              crc16_d = crc16(data_q[7:0], crc16_q);
              tx_valid = 1'b1;
              in_byte_d = in_byte_q + 1;
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
              if (in_iso_endps_i[endp_q] == 1'b1)
                in_data_ack = 1'b1;
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
             .bus_reset_o(bus_reset),
             .rx_ready_o(rx_ready),
             .clk_i(clk_i),
             .rstn_i(rstn_i),
             .clk_gate_i(clk_gate_i),
             .rx_en_i(rx_en),
             .usb_detach_i(usb_detach_i),
             .dp_rx_i(dp_rx_i),
             .dn_rx_i(dn_rx_i));

   phy_tx
     u_phy_tx (.tx_en_o(tx_en),
               .dp_tx_o(dp_tx_o),
               .dn_tx_o(dn_tx_o),
               .tx_ready_o(tx_ready),
               .clk_i(clk_i),
               .rstn_i(rstn),
               .clk_gate_i(clk_gate_i),
               .tx_valid_i(tx_valid),
               .tx_data_i(tx_data));
endmodule
