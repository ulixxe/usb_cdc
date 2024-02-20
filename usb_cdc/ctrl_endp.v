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
//       - GET_DESCRIPTOR (DEVICE, CONFIGURATION and STRING) (06h)
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
    parameter CHANNELS = 'd1,
    parameter CTRL_MAXPACKETSIZE = 'd8,
    parameter IN_BULK_MAXPACKETSIZE = 'd8,
    parameter OUT_BULK_MAXPACKETSIZE = 'd8)
   (
    // ---- to/from USB_CDC module ---------------------------------
    input         clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES.
    input         rstn_i,
    // While rstn_i is low (active low), the module shall be reset.
    input         clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.
    output        configured_o,
    // While USB_CDC is in configured state, configured_o shall be high.
    // When clk_gate_i is high, configured_o shall be updated.

    // ---- to/from SIE module ------------------------------------
    input         bus_reset_i,
    // While bus_reset_i is high, the module shall be reset.
    // When bus_reset_i is high, the device shall be in DEFAULT_STATE
    // When clk_gate_i is high, bus_reset_i shall be updated.
    output        usb_en_o,
    // While device is in POWERED_STATE and bus_reset_i is low, usb_en_o shall be low.
    // When clk_gate_i is high, usb_en_o shall be updated.
    output [6:0]  addr_o,
    // addr_o shall be the device address.
    // addr_o shall be updated at the end of SET_ADDRESS control transfer.
    // When clk_gate_i is high, addr_o shall be updated.
    output        stall_o,
    // While control pipe is addressed and is in stall state, stall_o shall
    //   be high, otherwise shall be low.
    // When clk_gate_i is high, stall_o shall be updated.
    output [15:0] in_bulk_endps_o,
    // While in_bulk_endps_o[i] is high, endp=i shall be enabled as IN bulk endpoint.
    //   endp=0 is reserved for IN control endpoint.
    // When clk_gate_i is high, in_bulk_endps_o shall be updated.
    output [15:0] out_bulk_endps_o,
    // While out_bulk_endps_o[i] is high, endp=i shall be enabled as OUT bulk endpoint
    //   endp=0 is reserved for OUT control endpoint.
    // When clk_gate_i is high, out_bulk_endps_o shall be updated.
    output [15:0] in_int_endps_o,
    // While in_int_endps_o[i] is high, endp=i shall be enabled as IN interrupt endpoint.
    //   endp=0 is reserved for IN control endpoint.
    // When clk_gate_i is high, in_int_endps_o shall be updated.
    output [15:0] out_int_endps_o,
    // While out_int_endps_i[i] is high, endp=i shall be enabled as OUT interrupt endpoint
    //   endp=0 is reserved for OUT control endpoint.
    // When clk_gate_i is high, out_int_endps_o shall be updated.
    output [15:0] out_toggle_reset_o,
    // When out_toggle_reset_o[i] is high, data toggle synchronization of
    //   OUT bulk pipe at endpoint=i shall be reset to DATA0.
    // When clk_gate_i is high, out_toggle_reset_o shall be updated.
    output [15:0] in_toggle_reset_o,
    // When in_toggle_reset_o[i] is high, data toggle synchronization of
    //   IN bulk pipe at endpoint=i shall be reset to DATA0.
    // When clk_gate_i is high, in_toggle_reset_o shall be updated.
    output [7:0]  in_data_o,
    // While in_valid_o is high and in_zlp_o is low, in_data_o shall be valid.
    output        in_zlp_o,
    // While IN Control Endpoint have to reply with zero length packet,
    //   IN Control Endpoint shall put both in_zlp_o and in_valid_o high.
    // When clk_gate_i is high, in_zlp_o shall be updated.
    output        in_valid_o,
    // While IN Control Endpoint have data or zero length packet available,
    //   IN Control Endpoint shall put in_valid_o high.
    // When clk_gate_i is high, in_valid_o shall be updated.
    input         in_req_i,
    // When both in_req_i and in_ready_i are high, a new IN packet shall be requested.
    // When clk_gate_i is high, in_req_i shall be updated.
    input         in_ready_i,
    // When both in_ready_i and in_valid_o are high, in_data_o or zero length
    //   packet shall be consumed.
    // When in_data_o or zlp is consumed, in_ready_i shall be high only for
    //   one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, in_ready_i shall be updated.
    input         setup_i,
    // While last correctly checked PID (USB2.0 8.3.1) is SETUP, setup_i shall
    //   be high, otherwise shall be low.
    // When clk_gate_i is high, setup_i shall be updated.
    input         in_data_ack_i,
    // When in_data_ack_i is high and out_ready_i is high, an ACK packet shall be received.
    // When clk_gate_i is high, in_data_ack_i shall be updated.
    input [7:0]   out_data_i,
    input         out_valid_i,
    // While out_valid_i is high, the out_data_i shall be valid and both
    //   out_valid_i and out_data_i shall not change until consumed.
    // When clk_gate_i is high, out_valid_i shall be updated.
    input         out_err_i,
    // When both out_err_i and out_ready_i are high, SIE shall abort the
    //   current packet reception and OUT Control Endpoint shall manage the error
    //   condition.
    // When clk_gate_i is high, out_err_i shall be updated.
    input         out_ready_i
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When setup_i is high and out_ready_i is high, a new SETUP transaction shall be
    //   received.
    // When setup_i, out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT packet shall end (EOP).
    // out_ready_i shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, out_ready_i shall be updated.
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

   function [7:0] master_interface;
      input integer channel;
      begin
         master_interface = 2*channel[6:0];
      end
   endfunction

   function [7:0] slave_interface;
      input integer channel;
      begin
         slave_interface = 2*channel[6:0]+1;
      end
   endfunction

   function [3:0] bulk_endp;
      input integer channel;
      begin
         bulk_endp = 2*channel[2:0]+1;
      end
   endfunction

   function [3:0] int_endp;
      input integer channel;
      begin
         int_endp = 2*channel[2:0]+2;
      end
   endfunction

   function [15:0] bulk_endps;
      input integer channels;
      integer       i;
      begin
         bulk_endps = 16'b0;
         for (i = 0; i < channels; i = i+1) begin
            bulk_endps[bulk_endp(i)] = 1'b1;
         end
      end
   endfunction

   function [15:0] int_endps;
      input integer channels;
      integer       i;
      begin
         int_endps = 16'b0;
         for (i = 0; i < channels; i = i+1) begin
            int_endps[int_endp(i)] = 1'b1;
         end
      end
   endfunction

   localparam [15:0] IN_BULK_ENDPS = bulk_endps(CHANNELS);
   localparam [15:0] OUT_BULK_ENDPS = bulk_endps(CHANNELS);
   localparam [15:0] IN_INT_ENDPS = int_endps(CHANNELS);
   localparam [15:0] OUT_INT_ENDPS = 16'b0;

   function [7:0] string_index;
      input integer channel;
      begin
         string_index = channel[7:0]+8'd1;
      end
   endfunction

   // String Descriptor Zero (in reverse order)
   localparam [8*'h4-1:0] STRING_DESCR_00 = {8'h04, // wLANGID[1] (US English)
                                             8'h09, // wLANGID[0]
                                             8'h03, // bDescriptorType (STRING)
                                             8'h04 // bLength
                                             }; // String Descriptor Zero, USB2.0 9.6.7, page 273-274, Table 9-15

   localparam             SDL = 'h0A; // STRING_DESCR_XX Length
   // String Descriptor (in reverse order)
   localparam [8*SDL-1:0] STRING_DESCR_XX = {8'h00, "0",
                                             8'h00, "C",
                                             8'h00, "D",
                                             8'h00, "C",
                                             8'h03, // bDescriptorType (STRING)
                                             SDL[7:0] // bLength
                                             }; // UNICODE String Descriptor, USB2.0 9.6.7, page 273-274, Table 9-16

   // Device Descriptor (in reverse order)
   localparam [8*'h12-1:0] DEV_DESCR = {8'h01, // bNumConfigurations
                                        8'h00, // iSerialNumber (no string)
                                        8'h00, // iProduct (no string)
                                        8'h00, // iManufacturer (no string)
                                        8'h01, // bcdDevice[1] (1.10)
                                        8'h10, // bcdDevice[0]
                                        PRODUCTID[15:8], // idProduct[1]
                                        PRODUCTID[7:0], // idProduct[0]
                                        VENDORID[15:8], // idVendor[1]
                                        VENDORID[7:0], // idVendor[0]
                                        CTRL_MAXPACKETSIZE[7:0], // bMaxPacketSize0
                                        (CHANNELS>1) ? {
                                                        8'h01, // bDeviceProtocol (Interface Association Descriptor)
                                                        8'h02, // bDeviceSubClass (Common Class)
                                                        8'hEF // bDeviceClass (Miscellaneous Device Class)
                                                        } : {
                                                             8'h00, // bDeviceProtocol (specified at interface level)
                                                             8'h00, // bDeviceSubClass (specified at interface level)
                                                             8'h02 // bDeviceClass (Communications Device Class)
                                                             },
                                        8'h02, // bcdUSB[1] (2.00)
                                        8'h00, // bcdUSB[0]
                                        8'h01, // bDescriptorType (DEVICE)
                                        8'h12 // bLength
                                        }; // Standard Device Descriptor, USB2.0 9.6.1, page 261-263, Table 9-8

   function [8*'h3A-1:0] cdc_descr;
      input integer i;
      begin
         // CDC Interfaces Descriptor (in reverse order)
         cdc_descr = {8'h00, // bInterval
                      8'h00, // wMaxPacketSize[1]
                      IN_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                      8'h02, // bmAttributes (bulk)
                      8'h80+{4'd0, bulk_endp(i)}, // bEndpointAddress (1 IN)
                      8'h05, // bDescriptorType (ENDPOINT)
                      8'h07, // bLength
                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                      8'h00, // bInterval
                      8'h00, // wMaxPacketSize[1]
                      OUT_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                      8'h02, // bmAttributes (bulk)
                      8'h00+{4'd0, bulk_endp(i)}, // bEndpointAddress (1 OUT)
                      8'h05, // bDescriptorType (ENDPOINT)
                      8'h07, // bLength
                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                      8'h00, // iInterface (no string)
                      8'h00, // bInterfaceProtocol
                      8'h00, // bInterfaceSubClass
                      8'h0A, // bInterfaceClass (CDC-Data)
                      8'h02, // bNumEndpoints
                      8'h00, // bAlternateSetting
                      slave_interface(i), // bInterfaceNumber
                      8'h04, // bDescriptorType (INTERFACE)
                      8'h09, // bLength
                      // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12

                      8'hFF, // bInterval (255 ms)
                      8'h00, // wMaxPacketSize[1]
                      8'h08, // wMaxPacketSize[0]
                      8'h03, // bmAttributes (interrupt)
                      8'h80+{4'd0, int_endp(i)}, // bEndpointAddress (2 IN)
                      8'h05, // bDescriptorType (ENDPOINT)
                      8'h07, // bLength
                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13

                      slave_interface(i), // bSlaveInterface0
                      master_interface(i), // bMasterInterface
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

                      (CHANNELS>1) ? string_index(i) : 8'h00, // iInterface (string / no string)
                      8'h01, // bInterfaceProtocol (AT Commands in ITU V.25ter)
                      8'h02, // bInterfaceSubClass (Abstract Control Model)
                      8'h02, // bInterfaceClass (Communications Device Class)
                      8'h01, // bNumEndpoints
                      8'h00, // bAlternateSetting
                      master_interface(i), // bInterfaceNumber
                      8'h04, // bDescriptorType (INTERFACE)
                      8'h09 // bLength
                      }; // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
      end
   endfunction

   function [8*'h08-1:0] ia_descr;
      input integer i;
      begin
         // Interfaces Association Descriptor (in reverse order)
         ia_descr = {8'h00, // iFunction (no string)
                     8'h01, // bFunctionProtocol (AT Commands in ITU V.25ter)
                     8'h02, // bFunctionSubClass (Abstract Control Model)
                     8'h02, // bFunctionClass (Communications Device Class)
                     8'h02, // bInterfaceCount
                     master_interface(i), // bFirstInterface
                     8'h0B, // bDescriptorType (INTERFACE ASSOCIATION)
                     8'h08 // bLength
                     }; // Interface Association Descriptor, USB2.0 ECN 9.X.Y, page 4-5, Table 9-Z
      end
   endfunction

   localparam CDL = (CHANNELS>1) ? ('h3A+'h08)*CHANNELS+'h09 : 'h3A+'h09; // CONF_DESCR Length
   function [8*CDL-1:0] conf_descr;
      input dummy;
      integer i;
      begin
         conf_descr[0 +:8*'h09] = {8'h32, // bMaxPower (100mA)
                                   8'h80, // bmAttributes (bus powered, no remote wakeup)
                                   8'h00, // iConfiguration (no string)
                                   8'h01, // bConfigurationValue
                                   8'd2*CHANNELS[7:0], // bNumInterfaces
                                   CDL[15:8], // wTotalLength[1]
                                   CDL[7:0], // wTotalLength[0]
                                   8'h02, // bDescriptorType (CONFIGURATION)
                                   8'h09 // bLength
                                   }; // Standard Configuration Descriptor, USB2.0 9.6.3, page 264-266, Table 9-10

         if (CHANNELS>1) begin
            for (i = 0; i < CHANNELS; i = i+1) begin
               conf_descr[i*8*('h3A+'h08)+8*'h09 +:8*('h3A+'h08)] = {cdc_descr(i), ia_descr(i)};
            end
         end else begin
            conf_descr[8*'h09 +:8*'h3A] = cdc_descr('d0);
         end
      end
   endfunction

   // Configuration Descriptor (in reverse order)
   localparam [8*CDL-1:0] CONF_DESCR = conf_descr(0);

   localparam [2:0]       ST_IDLE = 3'd0,
                          ST_STALL = 3'd1,
                          ST_SETUP = 3'd2,
                          ST_IN_DATA = 3'd3,
                          ST_OUT_DATA = 3'd4,
                          ST_PRE_IN_STATUS = 3'd5,
                          ST_IN_STATUS = 3'd6,
                          ST_OUT_STATUS = 3'd7;
   localparam [1:0]       REC_DEVICE = 2'd0,
                          REC_INTERFACE = 2'd1,
                          REC_ENDPOINT = 2'd2;
   // Supported Standard Requests
   localparam [7:0]       STD_REQ_GET_STATUS = 'd0,
                          STD_REQ_CLEAR_FEATURE = 'd1,
                          STD_REQ_SET_ADDRESS = 'd5,
                          STD_REQ_GET_DESCRIPTOR = 'd6,
                          STD_REQ_GET_CONFIGURATION = 'd8,
                          STD_REQ_SET_CONFIGURATION = 'd9,
                          STD_REQ_GET_INTERFACE = 'd10;
   // Supported ACM Class Requests
   localparam [7:0]       ACM_REQ_SET_LINE_CODING = 'h20,
                          ACM_REQ_GET_LINE_CODING = 'h21,
                          ACM_REQ_SET_CONTROL_LINE_STATE = 'h22,
                          ACM_REQ_SEND_BREAK = 'h23;
   localparam [3:0]       REQ_NONE = 4'd0,
                          REQ_CLEAR_FEATURE = 4'd1,
                          REQ_GET_CONFIGURATION = 4'd2,
                          REQ_GET_DESCRIPTOR = 4'd3,
                          REQ_GET_DESCRIPTOR_DEVICE = 4'd4,
                          REQ_GET_DESCRIPTOR_CONFIGURATION = 4'd5,
                          REQ_GET_DESCRIPTOR_STRING = 4'd6,
                          REQ_GET_INTERFACE = 4'd7,
                          REQ_GET_STATUS = 4'd8,
                          REQ_SET_ADDRESS = 4'd9,
                          REQ_SET_CONFIGURATION = 4'd10,
                          REQ_DUMMY = 4'd11,
                          REQ_UNSUPPORTED = 4'd12;
   localparam [1:0]       POWERED_STATE = 2'd0,
                          DEFAULT_STATE = 2'd1,
                          ADDRESS_STATE = 2'd2,
                          CONFIGURED_STATE = 2'd3;

   localparam             BC_WIDTH = ceil_log2(1+`max('h12, `max(CDL, (CHANNELS>1) ? SDL : 0)));
   localparam [15:0]      CTRL_ENDPS = 16'h01;

   reg [2:0]              state_q, state_d;
   reg [BC_WIDTH-1:0]     byte_cnt_q, byte_cnt_d;
   reg [BC_WIDTH-1:0]     max_length_q, max_length_d;
   reg                    in_dir_q, in_dir_d;
   reg                    class_q, class_d;
   reg [1:0]              rec_q, rec_d;
   reg [3:0]              req_q, req_d;
   reg [7:0]              string_index_q, string_index_d;
   reg [1:0]              dev_state_q, dev_state_d;
   reg [1:0]              dev_state_qq, dev_state_dd;
   reg [6:0]              addr_q, addr_d;
   reg [6:0]              addr_qq, addr_dd;
   reg                    in_endp_q, in_endp_d;
   reg [3:0]              endp_q, endp_d;
   reg [7:0]              in_data;
   reg                    in_zlp;
   reg                    in_valid;
   reg [15:0]             in_toggle_reset, out_toggle_reset;

   wire                   rstn;
   wire [15:0]            in_toggle_endps, out_toggle_endps;

   assign configured_o = (dev_state_qq == CONFIGURED_STATE) ? 1'b1 : 1'b0;
   assign addr_o = addr_qq;
   assign stall_o = (state_q == ST_STALL) ? 1'b1 : 1'b0;
   assign in_data_o = in_data;
   assign in_zlp_o = in_zlp;
   assign in_valid_o = in_valid;
   assign in_bulk_endps_o = IN_BULK_ENDPS;
   assign out_bulk_endps_o = OUT_BULK_ENDPS;
   assign in_int_endps_o = IN_INT_ENDPS;
   assign out_int_endps_o = OUT_INT_ENDPS;
   assign in_toggle_reset_o = in_toggle_reset;
   assign out_toggle_reset_o = out_toggle_reset;
   assign in_toggle_endps = IN_BULK_ENDPS|IN_INT_ENDPS|CTRL_ENDPS;
   assign out_toggle_endps = OUT_BULK_ENDPS|OUT_INT_ENDPS|CTRL_ENDPS;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         dev_state_qq <= POWERED_STATE;
      end else begin
         if (clk_gate_i) begin
            if (bus_reset_i)
              dev_state_qq <= DEFAULT_STATE;
            else if (in_ready_i | out_ready_i)
              dev_state_qq <= dev_state_dd;
         end
      end
   end

   assign usb_en_o = (dev_state_qq == POWERED_STATE) ? 1'b0 : 1'b1;
   assign rstn = rstn_i & ~bus_reset_i;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         state_q <= ST_IDLE;
         byte_cnt_q <= 'd0;
         max_length_q <= 'd0;
         in_dir_q <= 1'b0;
         class_q <= 1'b0;
         rec_q <= REC_DEVICE;
         req_q <= REQ_NONE;
         string_index_q <= 'd0;
         dev_state_q <= DEFAULT_STATE;
         addr_q <= 7'd0;
         addr_qq <= 7'd0;
         in_endp_q <= 1'b0;
         endp_q <= 4'b0;
      end else begin
         if (clk_gate_i) begin
            if (in_ready_i | out_ready_i) begin
               byte_cnt_q <= 'd0;
               if (out_ready_i & out_err_i) begin
                  if (state_q != ST_STALL)
                    state_q <= ST_IDLE;
               end else if (out_ready_i & setup_i) begin
                  state_q <= ST_SETUP;
               end else if ((in_ready_i == 1'b1 &&
                             ((state_q == ST_SETUP) ||
                              (state_q == ST_OUT_DATA && in_req_i == 1'b0) ||
                              (state_q == ST_PRE_IN_STATUS && in_req_i == 1'b0) ||
                              (state_q == ST_IN_STATUS && in_data_ack_i == 1'b0) ||
                              (state_q == ST_OUT_STATUS && in_req_i == 1'b0 && in_data_ack_i == 1'b0))) ||
                            (out_ready_i == 1'b1 &&
                             ((state_q == ST_IN_DATA) ||
                              (state_q == ST_PRE_IN_STATUS) ||
                              (state_q == ST_IN_STATUS) ||
                              (state_q == ST_OUT_STATUS && out_valid_i == 1'b1)))) begin
                  state_q <= ST_STALL;
               end else begin
                  state_q <= state_d;
                  byte_cnt_q <= byte_cnt_d;
                  max_length_q <= max_length_d;
                  in_dir_q <= in_dir_d;
                  class_q <= class_d;
                  rec_q <= rec_d;
                  req_q <= req_d;
                  string_index_q <= (CHANNELS>1) ? string_index_d : 8'd0;
                  dev_state_q <= dev_state_d;
                  addr_q <= addr_d;
                  addr_qq <= addr_dd;
                  in_endp_q <= in_endp_d;
                  endp_q <= endp_d;
               end
            end
         end
      end
   end

   always @(/*AS*/addr_q or addr_qq or byte_cnt_q or class_q
            or dev_state_q or dev_state_qq or endp_q or in_data_ack_i
            or in_dir_q or in_endp_q or in_req_i or in_toggle_endps
            or max_length_q or out_data_i or out_toggle_endps
            or out_valid_i or rec_q or req_q or state_q
            or string_index_q) begin
      state_d = state_q;
      byte_cnt_d = 'd0;
      max_length_d = max_length_q;
      in_dir_d = in_dir_q;
      class_d = class_q;
      rec_d = rec_q;
      req_d = req_q;
      string_index_d = string_index_q;
      dev_state_d = dev_state_q;
      dev_state_dd = dev_state_qq;
      addr_d = addr_q;
      addr_dd = addr_qq;
      in_endp_d = in_endp_q;
      endp_d = endp_q;
      in_data = 8'd0;
      in_zlp = 1'b0;
      in_valid = 1'b0;
      in_toggle_reset = 16'b0;
      out_toggle_reset = 16'b0;

      case (state_q)
        ST_IDLE, ST_STALL : begin
        end
        ST_SETUP : begin
           if (out_valid_i) begin
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
                             ((out_data_i == ACM_REQ_SET_LINE_CODING) ||
                              (out_data_i == ACM_REQ_GET_LINE_CODING) ||
                              (out_data_i == ACM_REQ_SET_CONTROL_LINE_STATE) ||
                              (out_data_i == ACM_REQ_SEND_BREAK)))
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
                        if (CHANNELS > 1 && out_data_i <= CHANNELS)
                          string_index_d = out_data_i;
                        else if (|out_data_i == 1'b1)
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
                        if (out_data_i == 8'd1 && |string_index_q == 1'b0)
                          req_d = REQ_GET_DESCRIPTOR_DEVICE;
                        else if (out_data_i == 8'd2 && |string_index_q == 1'b0)
                          req_d = REQ_GET_DESCRIPTOR_CONFIGURATION;
                        else if (CHANNELS > 1 && out_data_i == 8'd3)
                          req_d = REQ_GET_DESCRIPTOR_STRING;
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
                   endp_d = out_data_i[3:0];
                   case (req_q)
                     REQ_CLEAR_FEATURE : begin
                        if (!((rec_q == REC_ENDPOINT) &&
                              ((out_data_i[7] == 1'b1 && in_toggle_endps[out_data_i[3:0]] == 1'b1) ||
                               (out_data_i[7] == 1'b0 && out_toggle_endps[out_data_i[3:0]] == 1'b1))))
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
                     REQ_GET_DESCRIPTOR_STRING : begin
                     end
                     REQ_GET_INTERFACE : begin
                        if (!(out_data_i < 2*CHANNELS))
                          req_d = REQ_UNSUPPORTED;
                     end
                     REQ_GET_STATUS : begin
                        if (!(((rec_q == REC_DEVICE) && (|out_data_i == 1'b0)) ||
                              ((rec_q == REC_INTERFACE) && (out_data_i < 2*CHANNELS)) ||
                              ((rec_q == REC_ENDPOINT) &&
                               ((out_data_i[7] == 1'b1 && in_toggle_endps[out_data_i[3:0]] == 1'b1) ||
                                (out_data_i[7] == 1'b0 && out_toggle_endps[out_data_i[3:0]] == 1'b1)))))
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
                     REQ_GET_DESCRIPTOR_STRING : begin
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
                     REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION, REQ_GET_DESCRIPTOR_STRING : begin
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
                     REQ_GET_DESCRIPTOR_DEVICE, REQ_GET_DESCRIPTOR_CONFIGURATION, REQ_GET_DESCRIPTOR_STRING : begin
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
           end else begin // Setup Stage EOP
              if (byte_cnt_q == 'd8) begin
                 if (req_q == REQ_UNSUPPORTED)
                   state_d = ST_STALL;
                 else if (in_dir_q == 1'b1) begin // Control Read Data Stage
                    state_d = ST_IN_DATA;
                 end else begin
                    if (max_length_q == 'd0) begin // No-data Control Status Stage
                       state_d = ST_PRE_IN_STATUS;
                    end else begin // Control Write Data Stage
                       state_d = ST_OUT_DATA;
                    end
                 end
              end else
                state_d = ST_STALL;
           end
        end
        ST_IN_DATA : begin
           byte_cnt_d = byte_cnt_q;
           if (byte_cnt_q == max_length_q ||
               (byte_cnt_q == 'h12 && req_q == REQ_GET_DESCRIPTOR_DEVICE) ||
               (byte_cnt_q == CDL[BC_WIDTH-1:0] && req_q == REQ_GET_DESCRIPTOR_CONFIGURATION) ||
               (byte_cnt_q == 'h04 && req_q == REQ_GET_DESCRIPTOR_STRING && CHANNELS > 1 && string_index_q == 'h00) ||
               (byte_cnt_q == SDL[BC_WIDTH-1:0] && req_q == REQ_GET_DESCRIPTOR_STRING && CHANNELS > 1 && string_index_q != 'h00 && string_index_q <= CHANNELS)) begin
              if (in_data_ack_i) // Control Read Status Stage
                state_d = ST_OUT_STATUS;
              else if (~in_req_i)
                state_d = ST_STALL;
           end else begin
              if (~in_req_i & ~in_data_ack_i)
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
                   in_data = DEV_DESCR[{byte_cnt_q[ceil_log2('h12)-1:0], 3'd0} +:8];
                   in_valid = 1'b1;
                end
                REQ_GET_DESCRIPTOR_CONFIGURATION : begin
                   in_data = CONF_DESCR[{byte_cnt_q[ceil_log2(CDL)-1:0], 3'd0} +:8];
                   in_valid = 1'b1;
                end
                REQ_GET_DESCRIPTOR_STRING : begin
                   if(CHANNELS > 1 ) begin
                      if (string_index_q == 8'd0) begin
                         in_data = STRING_DESCR_00[{byte_cnt_q[ceil_log2('h4)-1:0], 3'd0} +:8];
                         in_valid = 1'b1;
                      end else if (string_index_q <= CHANNELS) begin
                         if (byte_cnt_q == SDL-2) begin
                            in_data = STRING_DESCR_XX[{byte_cnt_q[ceil_log2(SDL)-1:0], 3'd0} +:8] + string_index_q;
                            in_valid = 1'b1;
                         end else if (byte_cnt_q <= SDL-1) begin
                            in_data = STRING_DESCR_XX[{byte_cnt_q[ceil_log2(SDL)-1:0], 3'd0} +:8];
                            in_valid = 1'b1;
                         end
                      end
                   end
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
        ST_OUT_DATA : begin
           if (in_req_i) // Control Write Status Stage
             state_d = ST_IN_STATUS;
        end
        ST_PRE_IN_STATUS : begin
           state_d = ST_IN_STATUS;
        end
        ST_IN_STATUS : begin
           byte_cnt_d = byte_cnt_q;
           in_zlp = 1'b1;
           in_valid = 1'b1;
           state_d = ST_IDLE; // Status Stage ACK
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
                  in_toggle_reset[endp_q] = 1'b1;
                else
                  out_toggle_reset[endp_q] = 1'b1;
             end
             REQ_SET_CONFIGURATION : begin
                dev_state_dd = dev_state_q;
                in_toggle_reset = 16'hFFFF;
                out_toggle_reset = 16'hFFFF;
             end
             default : begin
             end
           endcase
        end
        ST_OUT_STATUS : begin
           if (~in_req_i & ~in_data_ack_i) begin // Status Stage EOP
              state_d = ST_IDLE;
           end
        end
        default : begin
           state_d = ST_IDLE;
        end
      endcase
   end
endmodule
