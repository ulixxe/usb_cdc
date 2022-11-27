//  USB 2.0 full speed IN/OUT Control Endpoints.
//  Written in verilog 2001

// CTRL_ENDP module shall implement IN/OUT Control Endpoint.
// CTRL_ENDP shall manage control transfers:
//   - Provide device information.
//   - Keep device states (Default, Address and Configured).
//   - Keep and provide to SIE the device address.
//   - Respond to standard device requests:
//       - GET_STATUS (00h)
//       - CLEAR_FEATURE (01h)
//       - SET_ADDRESS (05h)
//       - GET_DESCRIPTOR (DEVICE and CONFIGURATION) (06h)
//       - GET_CONFIGURATION (08h)
//       - SET_CONFIGURATION (09h)
//       - GET_INTERFACE (0Ah)
//   - Respond to Abstract Control Model (ACM) subclass requests:
//       - SET_LINE_CODING (20h)
//       - GET_LINE_CODING (21h)
//       - SET_CONTROL_LINE_STATE (22h)
//       - SEND_BREAK (23h)

`define max(a,b) ((a) > (b) ? (a) : (b))
`define min(a,b) ((a) < (b) ? (a) : (b))

module ctrl_endp
  #(parameter VENDORID = 16'h0000,
    parameter PRODUCTID = 16'h0000,
    parameter CTRL_MAXPACKETSIZE = 'd8,
    parameter IN_BULK_MAXPACKETSIZE = 'd8,
    parameter OUT_BULK_MAXPACKETSIZE = 'd8,
    parameter ENDP_BULK = 4'd1,
    parameter ENDP_INT = 4'd2)
   (
    // ---- to/from USB_CDC module ---------------------------------
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input        rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    output       configured_o,
    // While USB_CDC is in configured state, configured_o shall be high.

    // ---- to/from SIE module ------------------------------------
    input        usb_reset_i,
    // While usb_reset_i is high, the module shall be reset.
    output       usb_en_o,
    // While device is in POWERED_STATE and usb_reset_i is low, usb_en_o shall be low.
    output [6:0] addr_o,
    // addr_o shall be the device address.
    // addr_o shall be updated at the end of SET_ADDRESS control transfer.
    output       stall_o,
    // While control pipe is addressed and is in stall state, stall_o shall
    //   be high, otherwise shall be low.
    output       out_toggle_reset_o,
    // When out_toggle_reset_o is high, data toggle synchronization of
    //   OUT bulk pipe shall be reset to DATA0.
    output       in_toggle_reset_o,
    // When in_toggle_reset_o is high, data toggle synchronization of
    //   IN bulk pipe shall be reset to DATA0.
    output [7:0] in_data_o,
    // While in_valid_o is high and in_zlp_o is low, in_data_o shall be valid.
    output       in_zlp_o,
    // While in_req_i is high and IN Control Endpoint have to reply with zero length
    //   packet, IN Control Endpoint shall put both in_zlp_o and in_valid_o high.
    output       in_valid_o,
    // While in_req_i is high and IN Control Endpoint have data or zero length packet
    //   available, IN Control Endpoint shall put in_valid_o high.
    input        in_req_i,
    input        in_ready_i,
    // When both in_ready_i and in_valid_o are high, in_data_o or zero length
    //   packet shall be consumed.
    // When in_data_o or zlp is consumed, in_ready_i shall be high only for
    //   one clk_i period.
    input        setup_i,
    // While last correctly checked PID (USB2.0 8.3.1) is SETUP, setup_i shall
    //   be high, otherwise shall be low.
    input        in_data_ack_i,
    // When in_data_ack_i is high and out_ready_i is high, an ACK packet shall be received.
    input [7:0]  out_data_i,
    input        out_valid_i,
    // While out_valid_i is high, the out_data_i shall be valid and both
    //   out_valid_i and out_data_i shall not change until consumed.
    input        out_err_i,
    // When both out_err_i and out_ready_i are high, SIE shall abort the
    //   current packet reception and OUT Control Endpoint shall manage the error
    //   condition.
    input        out_ready_i
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When setup_i is high and out_ready_i is high, a new SETUP transaction shall be
    //   received.
    // When setup_i, in_data_ack_i, out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT transaction shall end.
    // out_ready_i shall be high only for one clk_i period.
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   // Device Descriptor (in reverse order)
   localparam [8*'h12-1:0] DEV_DESCR = {8'h01, // bNumConfigurations
                                        8'h00, // iSerialNumber (no string)
                                        8'h00, // iProduct (no string)
                                        8'h00, // iManufacturer (no string)
                                        8'h01, // bcdDevice[1] (1.00)
                                        8'h00, // bcdDevice[0]
                                        PRODUCTID[15:8], // idProduct[1]
                                        PRODUCTID[7:0], // idProduct[0]
                                        VENDORID[15:8], // idVendor[1]
                                        VENDORID[7:0], // idVendor[0]
                                        CTRL_MAXPACKETSIZE[7:0], // bMaxPacketSize0
                                        8'h00, // bDeviceProtocol (specified at interface level)
                                        8'h00, // bDeviceSubClass (specified at interface level)
                                        8'h02, // bDeviceClass (Communications Device Class)
                                        8'h02, // bcdUSB[1] (2.00)
                                        8'h00, // bcdUSB[0]
                                        8'h01, // bDescriptorType (DEVICE)
                                        8'h12 // bLength
                                        }; // Standard Device Descriptor, USB2.0 9.6.1, page 261-263, Table 9-8

   // Configuration Descriptor (in reverse order)
   localparam [8*'h43-1:0] CONF_DESCR = {8'h00, // bInterval
                                         8'h00, // wMaxPacketSize[1]
                                         IN_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                         8'h02, // bmAttributes (bulk)
                                         {4'h8, ENDP_BULK}, // bEndpointAddress (1 IN)
                                         8'h05, // bDescriptorType (ENDPOINT)
                                         8'h07, // bLength
                                         // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                                         8'h00, // bInterval
                                         8'h00, // wMaxPacketSize[1]
                                         OUT_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                         8'h02, // bmAttributes (bulk)
                                         {4'h0, ENDP_BULK}, // bEndpointAddress (1 OUT)
                                         8'h05, // bDescriptorType (ENDPOINT)
                                         8'h07, // bLength
                                         // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                                         8'h00, // iInterface (no string)
                                         8'h00, // bInterfaceProtocol
                                         8'h00, // bInterfaceSubClass
                                         8'h0A, // bInterfaceClass (CDC-Data)
                                         8'h02, // bNumEndpoints
                                         8'h00, // bAlternateSetting
                                         8'h01, // bInterfaceNumber
                                         8'h04, // bDescriptorType (INTERFACE)
                                         8'h09, // bLength
                                         // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12

                                         8'hFF, // bInterval (255 ms)
                                         8'h00, // wMaxPacketSize[1]
                                         8'h08, // wMaxPacketSize[0]
                                         8'h03, // bmAttributes (interrupt)
                                         {4'h8, ENDP_INT}, // bEndpointAddress (2 IN)
                                         8'h05, // bDescriptorType (ENDPOINT)
                                         8'h07, // bLength
                                         // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                                         8'h01, // bSlaveInterface0
                                         8'h00, // bMasterInterface
                                         8'h06, // bDescriptorSubtype (Union Functional)
                                         8'h24, // bDescriptorType (CS_INTERFACE)
                                         8'h05, // bFunctionLength
                                         // Union Functional Descriptor, CDC1.1 5.2.3.8, Table 33

                                         8'h00, // bmCapabilities (none)
                                         8'h02, // bDescriptorSubtype (Abstract Control Management Functional)
                                         8'h24, // bDescriptorType (CS_INTERFACE)
                                         8'h04, // bFunctionLength
                                         // Abstract Control Management Functional Descriptor, CDC1.1 5.2.3.3, Table 28

                                         8'h01, // bDataInterface
                                         8'h00, // bmCapabilities (no call mgmnt)
                                         8'h01, // bDescriptorSubtype (Call Management Functional)
                                         8'h24, // bDescriptorType (CS_INTERFACE)
                                         8'h05, // bFunctionLength
                                         // Call Management Functional Descriptor, CDC1.1 5.2.3.2, Table 27

                                         8'h01, // bcdCDC[1] (1.1)
                                         8'h10, // bcdCDC[0]
                                         8'h00, // bDescriptorSubtype (Header Functional)
                                         8'h24, // bDescriptorType (CS_INTERFACE)
                                         8'h05, // bFunctionLength
                                         // Header Functional Descriptor, CDC1.1 5.2.3.1, Table 26

                                         8'h00, // iInterface (no string)
                                         8'h01, // bInterfaceProtocol (AT Commands in ITU V.25ter)
                                         8'h02, // bInterfaceSubClass (Abstract Control Model)
                                         8'h02, // bInterfaceClass (Communications Device Class)
                                         8'h01, // bNumEndpoints
                                         8'h00, // bAlternateSetting
                                         8'h00, // bInterfaceNumber
                                         8'h04, // bDescriptorType (INTERFACE)
                                         8'h09, // bLength
                                         // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12

                                         8'h32, // bMaxPower (100mA)
                                         8'h80, // bmAttributes (bus powered, no remote wakeup)
                                         8'h00, // iConfiguration (no string)
                                         8'h01, // bConfigurationValue
                                         8'h02, // bNumInterfaces
                                         8'h00, // wTotalLength[1]
                                         8'h43, // wTotalLength[0]
                                         8'h02, // bDescriptorType (CONFIGURATION)
                                         8'h09 // bLength
                                         }; // Standard Configuration Descriptor, USB2.0 9.6.3, page 264-266, Table 9-10

   localparam [1:0]        ST_IDLE = 2'd0,
                           ST_STALL = 2'd1,
                           ST_SETUP = 2'd2,
                           ST_DATA = 2'd3;
   localparam [1:0]        REC_DEVICE = 2'd0,
                           REC_INTERFACE = 2'd1,
                           REC_ENDPOINT = 2'd2;
   // Supported Standard Requests
   localparam [7:0]        STD_REQ_GET_STATUS = 'd0,
                           STD_REQ_CLEAR_FEATURE = 'd1,
                           STD_REQ_SET_ADDRESS = 'd5,
                           STD_REQ_GET_DESCRIPTOR = 'd6,
                           STD_REQ_GET_CONFIGURATION = 'd8,
                           STD_REQ_SET_CONFIGURATION = 'd9,
                           STD_REQ_GET_INTERFACE = 'd10;
   // Supported Class Requests
   localparam [7:0]        CLASS_REQ_SET_LINE_CODING = 'h20,
                           CLASS_REQ_GET_LINE_CODING = 'h21,
                           CLASS_REQ_SET_CONTROL_LINE_STATE = 'h22,
                           CLASS_REQ_SEND_BREAK = 'h23;
   localparam [3:0]        REQ_NONE = 4'd0,
                           REQ_CLEAR_FEATURE = 4'd1,
                           REQ_GET_CONFIGURATION = 4'd2,
                           REQ_GET_DESCRIPTOR = 4'd3,
                           REQ_GET_DESCRIPTOR_DEVICE = 4'd4,
                           REQ_GET_DESCRIPTOR_CONFIGURATION = 4'd5,
                           REQ_GET_INTERFACE = 4'd6,
                           REQ_GET_STATUS = 4'd7,
                           REQ_SET_ADDRESS = 4'd8,
                           REQ_SET_CONFIGURATION = 4'd9,
                           REQ_DUMMY = 4'd10,
                           REQ_UNSUPPORTED = 4'd11;
   localparam [1:0]        POWERED_STATE = 2'd0,
                           DEFAULT_STATE = 2'd1,
                           ADDRESS_STATE = 2'd2,
                           CONFIGURED_STATE = 2'd3;

   localparam              BC_WIDTH = ceil_log2(`max('h43,'h12));

   reg [1:0]               state_q, state_d;
   reg [BC_WIDTH-1:0]      byte_cnt_q, byte_cnt_d;
   reg [BC_WIDTH-1:0]      max_length_q, max_length_d;
   reg                     in_dir_q, in_dir_d;
   reg                     class_q, class_d;
   reg [1:0]               rec_q, rec_d;
   reg [3:0]               req_q, req_d;
   reg [1:0]               dev_state_q, dev_state_d;
   reg [1:0]               dev_state_qq, dev_state_dd;
   reg [6:0]               addr_q, addr_d;
   reg [6:0]               addr_qq, addr_dd;
   reg                     in_endp_q, in_endp_d;
   reg [7:0]               in_data;
   reg                     in_zlp;
   reg                     in_valid;
   reg                     in_toggle_reset, out_toggle_reset;
   reg                     in_req_q;
   reg                     usb_reset_q;

   wire                    clk_gate;
   wire                    rstn;

   assign configured_o = (dev_state_qq == CONFIGURED_STATE) ? 1'b1 : 1'b0;
   assign addr_o = addr_qq;
   assign stall_o = (state_q == ST_STALL) ? 1'b1 : 1'b0;
   assign in_data_o = in_data;
   assign in_zlp_o = in_zlp & in_req_q;
   assign in_valid_o = in_valid & in_req_q;
   assign in_toggle_reset_o = in_toggle_reset;
   assign out_toggle_reset_o = out_toggle_reset;

   assign clk_gate = in_ready_i | out_ready_i;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_req_q <= 1'b0;
         usb_reset_q <= 1'b0;
         dev_state_qq <= POWERED_STATE;
      end else begin
         in_req_q <= in_req_i;
         usb_reset_q <= usb_reset_i | usb_reset_q;
         if (clk_gate) begin
            if (usb_reset_q) begin
               usb_reset_q <= 1'b0;
               dev_state_qq <= DEFAULT_STATE;
            end else
              dev_state_qq <= dev_state_dd;
         end
      end
   end

   assign usb_en_o = (dev_state_qq == POWERED_STATE && usb_reset_q == 1'b0) ? 1'b0 : 1'b1;
   assign rstn = rstn_i & ~usb_reset_i;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         state_q <= ST_IDLE;
         byte_cnt_q <= 'd0;
         max_length_q <= 'd0;
         in_dir_q <= 1'b0;
         class_q <= 1'b0;
         rec_q <= REC_DEVICE;
         req_q <= REQ_NONE;
         dev_state_q <= DEFAULT_STATE;
         addr_q <= 7'd0;
         addr_qq <= 7'd0;
         in_endp_q <= 1'b0;
      end else begin
         if (clk_gate) begin
            state_q <= state_d;
            byte_cnt_q <= byte_cnt_d;
            max_length_q <= max_length_d;
            in_dir_q <= in_dir_d;
            class_q <= class_d;
            rec_q <= rec_d;
            req_q <= req_d;
            dev_state_q <= dev_state_d;
            addr_q <= addr_d;
            addr_qq <= addr_dd;
            in_endp_q <= in_endp_d;
         end
      end
   end

   always @(/*AS*/addr_q or addr_qq or byte_cnt_q or class_q
            or dev_state_q or dev_state_qq or in_data_ack_i
            or in_dir_q or in_endp_q or in_req_q or max_length_q
            or out_data_i or out_err_i or out_valid_i or rec_q
            or req_q or setup_i or state_q) begin
      state_d = state_q;
      byte_cnt_d = 'd0;
      max_length_d = max_length_q;
      in_dir_d = in_dir_q;
      class_d = class_q;
      rec_d = rec_q;
      req_d = req_q;
      dev_state_d = dev_state_q;
      dev_state_dd = dev_state_qq;
      addr_d = addr_q;
      addr_dd = addr_qq;
      in_endp_d = in_endp_q;
      in_data = 8'd0;
      in_zlp = 1'b0;
      in_valid = 1'b0;
      in_toggle_reset = 1'b0;
      out_toggle_reset = 1'b0;

      if (out_err_i == 1'b1) begin
         if (state_q != ST_STALL)
           state_d = ST_IDLE;
      end else if (setup_i == 1'b1) begin
         state_d = ST_SETUP;
      end else begin
         case (state_q)
           ST_IDLE, ST_STALL : begin
           end
           ST_SETUP : begin
              if (out_valid_i == 1'b1) begin
                 byte_cnt_d = byte_cnt_q + 1;
                 case (byte_cnt_q)
                   'd0 : begin // bmRequestType
                      in_dir_d = out_data_i[7];
                      class_d = out_data_i[5];
                      rec_d = out_data_i[1:0];
                      if (out_data_i[6] == 1'b1 || |out_data_i[4:2] != 1'b0 || out_data_i[1:0] == 2'b11)
                        req_d = REQ_UNSUPPORTED;
                      else
                        req_d = REQ_NONE;
                   end
                   'd1 : begin // bRequest
                      req_d = REQ_UNSUPPORTED;
                      if (req_q == REQ_NONE) begin
                         if (class_q == 1'b0) begin
                            case (out_data_i)
                              STD_REQ_CLEAR_FEATURE : begin
                                 if (in_dir_q == 1'b0 && dev_state_qq != DEFAULT_STATE)
                                   req_d = REQ_CLEAR_FEATURE;
                              end
                              STD_REQ_GET_CONFIGURATION : begin
                                 if (in_dir_q == 1'b1 && rec_q == REC_DEVICE && dev_state_qq != DEFAULT_STATE)
                                   req_d = REQ_GET_CONFIGURATION;
                              end
                              STD_REQ_GET_DESCRIPTOR : begin
                                 if (in_dir_q == 1'b1 && rec_q == REC_DEVICE)
                                   req_d = REQ_GET_DESCRIPTOR;
                              end
                              STD_REQ_GET_INTERFACE : begin
                                 if (in_dir_q == 1'b1 && rec_q == REC_INTERFACE && dev_state_qq == CONFIGURED_STATE)
                                   req_d = REQ_GET_INTERFACE;
                              end
                              STD_REQ_GET_STATUS : begin
                                 if (in_dir_q == 1'b1 && dev_state_qq != DEFAULT_STATE)
                                   req_d = REQ_GET_STATUS;
                              end
                              STD_REQ_SET_ADDRESS : begin
                                 if (in_dir_q == 1'b0 && rec_q == REC_DEVICE)
                                   req_d = REQ_SET_ADDRESS;
                              end
                              STD_REQ_SET_CONFIGURATION : begin
                                 if (in_dir_q == 1'b0 && rec_q == REC_DEVICE && dev_state_qq != DEFAULT_STATE)
                                   req_d = REQ_SET_CONFIGURATION;
                              end
                              default : begin
                              end
                            endcase
                         end else begin
                            if (dev_state_qq == CONFIGURED_STATE &&
                                ((out_data_i == CLASS_REQ_SET_LINE_CODING) ||
                                 (out_data_i == CLASS_REQ_GET_LINE_CODING) ||
                                 (out_data_i == CLASS_REQ_SET_CONTROL_LINE_STATE) ||
                                 (out_data_i == CLASS_REQ_SEND_BREAK)))
                              req_d = REQ_DUMMY;
                         end
                      end
                   end
                   'd2 : begin // wValue LSB
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin // ENDPOINT_HALT
                           if (!(rec_q == REC_ENDPOINT && |out_data_i == 1'b0))
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_INTERFACE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (out_data_i[7] == 1'b0)
                             addr_d = out_data_i[6:0];
                           else
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (out_data_i == 8'd0)
                             dev_state_d = ADDRESS_STATE;
                           else if (out_data_i == 8'd1)
                             dev_state_d = CONFIGURED_STATE;
                           else
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   'd3 : begin // wValue MSB
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR : begin
                           if (out_data_i == 8'd1)
                             req_d = REQ_GET_DESCRIPTOR_DEVICE;
                           else if (out_data_i == 8'd2)
                             req_d = REQ_GET_DESCRIPTOR_CONFIGURATION;
                           else
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_INTERFACE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   'd4 : begin // wIndex LSB
                      in_endp_d = out_data_i[7];
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin
                           if (!((rec_q == REC_ENDPOINT) &&
                                 (out_data_i == 8'h00 || out_data_i == 8'h80 ||
                                  out_data_i == 8'h01 || out_data_i == 8'h81 ||
                                  out_data_i == 8'h82)))
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_INTERFACE : begin
                           if (!(out_data_i == 8'd0 || out_data_i == 8'd1))
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (!(((rec_q == REC_DEVICE) && (|out_data_i == 1'b0)) ||
                                 ((rec_q == REC_INTERFACE) && (|out_data_i[7:1] == 1'b0)) ||
                                 ((rec_q == REC_ENDPOINT) &&
                                  (out_data_i == 8'h00 || out_data_i == 8'h80 ||
                                   out_data_i == 8'h01 || out_data_i == 8'h81 ||
                                   out_data_i == 8'h82))))
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   'd5 : begin // wIndex MSB
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_INTERFACE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   'd6 : begin // wLength LSB
                      max_length_d[`min(BC_WIDTH-1, 7):0] = out_data_i[`min(BC_WIDTH-1, 7):0];
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (out_data_i != 8'd1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                           if (BC_WIDTH < 8 && |out_data_i[7:`min(BC_WIDTH, 7)] == 1'b1)
                             max_length_d = {BC_WIDTH{1'b1}};
                        end
                        REQ_GET_INTERFACE : begin
                           if (out_data_i != 8'd1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (out_data_i != 8'd2)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   'd7 : begin // wLength MSB
                      if (BC_WIDTH > 8)
                        max_length_d[BC_WIDTH-1:`min(8, BC_WIDTH-1)] = out_data_i[BC_WIDTH-1-`min(8, BC_WIDTH-1):0];
                      case (req_q)
                        REQ_CLEAR_FEATURE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                           if (BC_WIDTH < 16 && |out_data_i[7:`min(`max(BC_WIDTH-8, 0), 7)] == 1'b1)
                             max_length_d = {BC_WIDTH{1'b1}};
                        end
                        REQ_GET_INTERFACE : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_GET_STATUS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_ADDRESS : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        REQ_SET_CONFIGURATION : begin
                           if (|out_data_i == 1'b1)
                             req_d = REQ_UNSUPPORTED;
                        end
                        default : begin
                        end
                      endcase
                   end
                   default : begin
                   end
                 endcase
              end else begin
                 if (byte_cnt_q == 'd8) begin
                    if (req_q == REQ_UNSUPPORTED)
                      state_d = ST_STALL;
                    else if (in_dir_q == 1'b1) begin
                       state_d = ST_DATA;
                    end else begin
                       if (max_length_q == 'd0) begin // No-data Control STATUS stage
                          byte_cnt_d = byte_cnt_q;
                          in_zlp = 1'b1;
                          in_valid = 1'b1;
                          if (in_data_ack_i) begin
                             state_d = ST_IDLE;
                             case (req_q)
                               REQ_SET_ADDRESS : begin
                                  addr_dd = addr_q;
                                  if (addr_q == 7'd0)
                                    dev_state_dd = DEFAULT_STATE;
                                  else
                                    dev_state_dd = ADDRESS_STATE;
                               end
                               REQ_CLEAR_FEATURE : begin
                                  if (in_endp_q == 1'b1)
                                    in_toggle_reset = 1'b1;
                                  else
                                    out_toggle_reset = 1'b1;
                               end
                               REQ_SET_CONFIGURATION : begin
                                  dev_state_dd = dev_state_q;
                                  in_toggle_reset = 1'b1;
                                  out_toggle_reset = 1'b1;
                               end
                               default : begin
                               end
                             endcase
                          end
                       end else
                         state_d = ST_DATA;
                    end
                 end else
                   state_d = ST_STALL;
              end
           end
           ST_DATA : begin
              byte_cnt_d = byte_cnt_q;
              if (in_dir_q == 1'b1) begin
                 if (out_valid_i == 1'b1) begin
                    state_d = ST_STALL;
                 end else begin
                    if (byte_cnt_q == max_length_q ||
                        (byte_cnt_q == 'h12 && req_q == REQ_GET_DESCRIPTOR_DEVICE) ||
                        (byte_cnt_q == 'h43 && req_q == REQ_GET_DESCRIPTOR_CONFIGURATION)) begin
                       if (in_req_q == 1'b0) begin
                          if (~in_data_ack_i) begin // Control Read STATUS stage
                             state_d = ST_IDLE;
                          end
                       end else
                         state_d = ST_STALL;
                    end else begin
                       if (in_req_q == 1'b1)
                         byte_cnt_d = byte_cnt_q + 1;
                       case (req_q)
                         REQ_GET_CONFIGURATION : begin
                            if (dev_state_qq == ADDRESS_STATE) begin
                               in_data = 8'd0;
                               in_valid = 1'b1;
                            end else if (dev_state_qq == CONFIGURED_STATE) begin
                               in_data = 8'd1;
                               in_valid = 1'b1;
                            end
                         end
                         REQ_GET_DESCRIPTOR_DEVICE : begin
                            in_data = DEV_DESCR[8*byte_cnt_q +:8];
                            in_valid = 1'b1;
                         end
                         REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                            in_data = CONF_DESCR[8*byte_cnt_q +:8];
                            in_valid = 1'b1;
                         end
                         REQ_GET_INTERFACE : begin
                            in_data = 8'd0;
                            in_valid = 1'b1;
                         end
                         REQ_GET_STATUS : begin
                            in_data = 8'd0;
                            in_valid = 1'b1;
                         end
                         default : begin
                            in_data = 8'd0;
                            in_valid = 1'b1;
                         end
                       endcase
                    end
                 end
              end else begin
                 in_zlp = 1'b1;
                 in_valid = 1'b1;
                 if (in_req_q == 1'b1)
                   state_d = ST_STALL;
                 else if (out_valid_i == 1'b1) begin
                 end else begin
                    if (in_data_ack_i) // Control Write STATUS stage
                      state_d = ST_IDLE;
                 end
              end
           end
           default : begin
              state_d = ST_IDLE;
           end
         endcase
      end
   end
endmodule
