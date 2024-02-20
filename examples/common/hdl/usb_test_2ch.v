
`include "usb_tasks.v"


localparam CHANNELS = 'd2;
localparam [3:0] ENDP_BULK1 = 'd1,
                 ENDP_INT1 = 'd2,
                 ENDP_BULK2 = 'd3,
                 ENDP_INT2 = 'd4;

localparam [8*'h12-1:0] DEV_DESCR = { // Standard Device Descriptor, USB2.0 9.6.1, page 261-263, Table 9-8
                                      8'h12, // bLength
                                      8'h01, // bDescriptorType (DEVICE)
                                      8'h00, // bcdUSB[0]
                                      8'h02, // bcdUSB[1] (2.00)
                                      8'hEF, // bDeviceClass (Miscellaneous Device Class)
                                      8'h02, // bDeviceSubClass (Common Class)
                                      8'h01, // bDeviceProtocol (Interface Association Descriptor)
                                      CTRL_MAXPACKETSIZE[7:0], // bMaxPacketSize0
                                      VENDORID[7:0], // idVendor[0]
                                      VENDORID[15:8], // idVendor[1]
                                      PRODUCTID[7:0], // idProduct[0]
                                      PRODUCTID[15:8], // idProduct[1]
                                      8'h10, // bcdDevice[0]
                                      8'h01, // bcdDevice[1] (1.10)
                                      8'h00, // iManufacturer (no string)
                                      8'h00, // iProduct (no string)
                                      8'h00, // iSerialNumber (no string)
                                      8'h01}; // bNumConfigurations

localparam CDL = ('h3A+'h08)*CHANNELS+'h09; // CONF_DESCR Length
localparam [8*CDL-1:0] CONF_DESCR = { // Standard Configuration Descriptor, USB2.0 9.6.3, page 264-266, Table 9-10
                                      8'h09, // bLength
                                      8'h02, // bDescriptorType (CONFIGURATION)
                                      CDL[7:0], // wTotalLength[0]
                                      CDL[15:8], // wTotalLength[1]
                                      8'd2*CHANNELS[7:0], // bNumInterfaces
                                      8'h01, // bConfigurationValue
                                      8'h00, // iConfiguration (no string)
                                      8'h80, // bmAttributes (bus powered, no remote wakeup)
                                      8'h32, // bMaxPower (100mA)

                                      // Interface Association Descriptor, USB2.0 ECN 9.X.Y, page 4-5, Table 9-Z
                                      8'h08, // bLength
                                      8'h0B, // bDescriptorType (INTERFACE ASSOCIATION)
                                      8'd2*8'd0, // bFirstInterface
                                      8'h02, // bInterfaceCount
                                      8'h02, // bFunctionClass (Communications Device Class)
                                      8'h02, // bFunctionSubClass (Abstract Control Model)
                                      8'h01, // bFunctionProtocol (AT Commands in ITU V.25ter)
                                      8'h00, // iFunction (no string)

                                      // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                      8'h09, // bLength
                                      8'h04, // bDescriptorType (INTERFACE)
                                      8'd2*8'd0, // bInterfaceNumber
                                      8'h00, // bAlternateSetting
                                      8'h01, // bNumEndpoints
                                      8'h02, // bInterfaceClass (Communications Device Class)
                                      8'h02, // bInterfaceSubClass (Abstract Control Model)
                                      8'h01, // bInterfaceProtocol (AT Commands in ITU V.25ter)
                                      8'd0+8'd1, // iInterface (string)

                                      // Header Functional Descriptor, CDC1.1 5.2.3.1, Table 26
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h00, // bDescriptorSubtype (Header Functional)
                                      8'h10, // bcdCDC[0]
                                      8'h01, // bcdCDC[1] (1.1)

                                      // Call Management Functional Descriptor, CDC1.1 5.2.3.2, Table 27
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h01, // bDescriptorSubtype (Call Management Functional)
                                      8'h00, // bmCapabilities (no call mgmnt)
                                      8'h01, // bDataInterface

                                      // Abstract Control Management Functional Descriptor, CDC1.1 5.2.3.3, Table 28
                                      8'h04, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h02, // bDescriptorSubtype (Abstract Control Management Functional)
                                      8'h00, // bmCapabilities (none)

                                      // Union Functional Descriptor, CDC1.1 5.2.3.8, Table 33
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h06, // bDescriptorSubtype (Union Functional)
                                      8'd2*8'd0, // bMasterInterface
                                      8'd2*8'd0+8'd1, // bSlaveInterface0

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h8, ENDP_INT1}, // bEndpointAddress (2 IN)
                                      8'h03, // bmAttributes (interrupt)
                                      8'h08, // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'hFF, // bInterval (255 ms)

                                      // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                      8'h09, // bLength
                                      8'h04, // bDescriptorType (INTERFACE)
                                      8'd2*8'd0+8'd1, // bInterfaceNumber
                                      8'h00, // bAlternateSetting
                                      8'h02, // bNumEndpoints
                                      8'h0A, // bInterfaceClass (data)
                                      8'h00, // bInterfaceSubClass
                                      8'h00, // bInterfaceProtocol
                                      8'h00, // iInterface (no string)

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h0, ENDP_BULK1}, // bEndpointAddress (1 OUT)
                                      8'h02, // bmAttributes (bulk)
                                      OUT_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'h00, // bInterval

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h8, ENDP_BULK1}, // bEndpointAddress (1 IN)
                                      8'h02, // bmAttributes (bulk)
                                      IN_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'h00, // bInterval

                                      // Interface Association Descriptor, USB2.0 ECN 9.X.Y, page 4-5, Table 9-Z
                                      8'h08, // bLength
                                      8'h0B, // bDescriptorType (INTERFACE ASSOCIATION)
                                      8'd2*8'd1, // bFirstInterface
                                      8'h02, // bInterfaceCount
                                      8'h02, // bFunctionClass (Communications Device Class)
                                      8'h02, // bFunctionSubClass (Abstract Control Model)
                                      8'h01, // bFunctionProtocol (AT Commands in ITU V.25ter)
                                      8'h00, // iFunction (no string)

                                      // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                      8'h09, // bLength
                                      8'h04, // bDescriptorType (INTERFACE)
                                      8'd2*8'd1, // bInterfaceNumber
                                      8'h00, // bAlternateSetting
                                      8'h01, // bNumEndpoints
                                      8'h02, // bInterfaceClass (Communications Device Class)
                                      8'h02, // bInterfaceSubClass (Abstract Control Model)
                                      8'h01, // bInterfaceProtocol (AT Commands in ITU V.25ter)
                                      8'd1+8'd1, // iInterface (string)

                                      // Header Functional Descriptor, CDC1.1 5.2.3.1, Table 26
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h00, // bDescriptorSubtype (Header Functional)
                                      8'h10, // bcdCDC[0]
                                      8'h01, // bcdCDC[1] (1.1)

                                      // Call Management Functional Descriptor, CDC1.1 5.2.3.2, Table 27
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h01, // bDescriptorSubtype (Call Management Functional)
                                      8'h00, // bmCapabilities (no call mgmnt)
                                      8'h01, // bDataInterface

                                      // Abstract Control Management Functional Descriptor, CDC1.1 5.2.3.3, Table 28
                                      8'h04, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h02, // bDescriptorSubtype (Abstract Control Management Functional)
                                      8'h00, // bmCapabilities (none)

                                      // Union Functional Descriptor, CDC1.1 5.2.3.8, Table 33
                                      8'h05, // bFunctionLength
                                      8'h24, // bDescriptorType (CS_INTERFACE)
                                      8'h06, // bDescriptorSubtype (Union Functional)
                                      8'd2*8'd1, // bMasterInterface
                                      8'd2*8'd1+8'd1, // bSlaveInterface0

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h8, ENDP_INT2}, // bEndpointAddress (4 IN)
                                      8'h03, // bmAttributes (interrupt)
                                      8'h08, // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'hFF, // bInterval (255 ms)

                                      // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                      8'h09, // bLength
                                      8'h04, // bDescriptorType (INTERFACE)
                                      8'd2*8'd1+8'd1, // bInterfaceNumber
                                      8'h00, // bAlternateSetting
                                      8'h02, // bNumEndpoints
                                      8'h0A, // bInterfaceClass (data)
                                      8'h00, // bInterfaceSubClass
                                      8'h00, // bInterfaceProtocol
                                      8'h00, // iInterface (no string)

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h0, ENDP_BULK2}, // bEndpointAddress (3 OUT)
                                      8'h02, // bmAttributes (bulk)
                                      OUT_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'h00, // bInterval

                                      // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                      8'h07, // bLength
                                      8'h05, // bDescriptorType (ENDPOINT)
                                      {4'h8, ENDP_BULK2}, // bEndpointAddress (3 IN)
                                      8'h02, // bmAttributes (bulk)
                                      IN_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                      8'h00, // wMaxPacketSize[1]
                                      8'h00}; // bInterval

// String Descriptor Zero
localparam [8*'h4-1:0]  STRING_DESCR_00 = {
                                           // String Descriptor Zero, USB2.0 9.6.7, page 273-274, Table 9-15
                                           8'h04, // bLength
                                           8'h03, // bDescriptorType (STRING)
                                           8'h09, // wLANGID[0]
                                           8'h04 // wLANGID[1] (US English)
                                           };

localparam SDL = 'h0A; // STRING_DESCR_xx Length
localparam [8*SDL-1:0]  STRING_DESCR_01 = {
                                           // UNICODE String Descriptor, USB2.0 9.6.7, page 273-274, Table 9-16
                                           SDL[7:0], // bLength
                                           8'h03, // bDescriptorType (STRING)
                                           "C", 8'h00,
                                           "D", 8'h00,
                                           "C", 8'h00,
                                           "1", 8'h00
                                           };
localparam [8*SDL-1:0]  STRING_DESCR_02 = {
                                           // UNICODE String Descriptor, USB2.0 9.6.7, page 273-274, Table 9-16
                                           SDL[7:0], // bLength
                                           8'h03, // bDescriptorType (STRING)
                                           "C", 8'h00,
                                           "D", 8'h00,
                                           "C", 8'h00,
                                           "2", 8'h00
                                           };


task automatic test_usb
  (
   inout [6:0]  address,
   inout [15:0] datain_toggle,
   inout [15:0] dataout_toggle
   );
   begin

      test = "SOF packet";
      test_sof(11'h113, 11'h000);

      test = "USB reset";
      test_usb_reset(address);

      test = "SOF packet";
      test_sof(11'h113, 11'h113);

      test = "SOF packet with CRC error";
      test_sof_crc_error(11'h113);

      test = "GET_DESCRIPTOR Device";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0100, 16'h0000, 16'h0040,
                    DEV_DESCR, 'h12, PID_ACK, NO_ZLP);

      test = "GET_DESCRIPTOR Device (partial)";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0100, 16'h0000, 16'h0008,
                    DEV_DESCR>>8*('h12-'h08), 'h08, PID_ACK, NO_ZLP);

      test = "GET_STATUS Error in Default state";
      test_setup_in(address, 8'h80, STD_REQ_GET_STATUS, 16'h0000, 16'h0000, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_STALL, NO_ZLP);

      test = "SET_ADDRESS";
      test_set_address('d2, address);

      test = "GET_STATUS on device";
      test_setup_in(address, 8'h80, STD_REQ_GET_STATUS, 16'h0000, 16'h0000, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_ACK, NO_ZLP);

      test = "GET_STATUS on inteface 3";
      test_setup_in(address, 8'h81, STD_REQ_GET_STATUS, 16'h0000, 16'h0003, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_ACK, NO_ZLP);

      test = "GET_STATUS stall on not-existent inteface";
      test_setup_in(address, 8'h81, STD_REQ_GET_STATUS, 16'h0000, 16'h0004, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_STALL, NO_ZLP);

      test = "GET_STATUS on OUT endpoint 3";
      test_setup_in(address, 8'h82, STD_REQ_GET_STATUS, 16'h0000, 16'h0003, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_ACK, NO_ZLP);

      test = "GET_STATUS stall on not-existent endpoint";
      test_setup_in(address, 8'h82, STD_REQ_GET_STATUS, 16'h0000, 16'h0085, 16'h0002,
                    {8'h00, 8'h00}, 'h02, PID_STALL, NO_ZLP);

      test = "CLEAR_FEATURE on OUT endpoint 0";
      test_setup_out(address, 8'h02, STD_REQ_CLEAR_FEATURE, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 'd0, PID_ACK);

      test = "CLEAR_FEATURE on IN endpoint 3";
      test_setup_out(address, 8'h02, STD_REQ_CLEAR_FEATURE, 16'h0000, 16'h0083, 16'h0000,
                     8'd0, 'd0, PID_ACK);

      test = "CLEAR_FEATURE stall on not-existent endpoint";
      test_setup_out(address, 8'h02, STD_REQ_CLEAR_FEATURE, 16'h0000, 16'h0004, 16'h0000,
                     8'd0, 'd0, PID_STALL);

      test = "USB reset";
      test_usb_reset(address);

      test = "SET_ADDRESS";
      test_set_address('d7, address);

      test = "Power-on reset";
      test_poweron_reset(address);

      test = "USB reset";
      test_usb_reset(address);

      test = "SET_ADDRESS";
      test_set_address('d3, address);

      test = "GET_DESCRIPTOR Configuration";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0200, 16'h0000, 16'h00FF,
                    CONF_DESCR, CDL, PID_ACK, NO_ZLP);

      test = "GET_DESCRIPTOR String Zero";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0300, 16'h0000, 16'h00FF,
                    STRING_DESCR_00, 'h4, PID_ACK, NO_ZLP);

      test = "GET_DESCRIPTOR String 01";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0301, 16'h0000, 16'h00FF,
                    STRING_DESCR_01, SDL, PID_ACK, NO_ZLP);

      test = "GET_DESCRIPTOR String 02";
      test_setup_in(address, 8'h80, STD_REQ_GET_DESCRIPTOR, 16'h0302, 16'h0000, 16'h00FF,
                    STRING_DESCR_02, SDL, PID_ACK, NO_ZLP);

      test = "SET_CONFIGURATION";
      test_set_configuration(address);

      test = "GET_LINE_CODING";
      test_setup_in(address, 8'hA1, ACM_REQ_GET_LINE_CODING, 16'h0000, 16'h0000, 16'h0007,
                    {7{8'd0}}, 7, PID_ACK, NO_ZLP);

      test = "SET_LINE_CODING";
      test_setup_out(address, 8'h21, ACM_REQ_SET_LINE_CODING, 16'h0000, 16'h0000, 16'h0007,
                     {7{8'd0}}, 7, PID_ACK);

      test = "SET_CONTROL_LINE_STATE";
      test_setup_out(address, 8'h21, ACM_REQ_SET_CONTROL_LINE_STATE, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 0, PID_ACK);

      test = "SEND_BREAK";
      test_setup_out(address, 8'h21, ACM_REQ_SEND_BREAK, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 0, PID_ACK);

      test = "GET_INTERFACE";
      test_setup_in(address, 8'h81, STD_REQ_GET_INTERFACE, 16'h0000, 16'h0001, 16'h0001,
                    8'd0, 1, PID_ACK, NO_ZLP);

      test = "SET_INTERFACE not supported";
      test_setup_out(address, 8'h01, STD_REQ_SET_INTERFACE, 16'h0001, 16'h0001, 16'h0000,
                     8'd0, 0, PID_STALL);

      test = "IN INT DATA";
      test_data_in(address, ENDP_INT1, 8'd0, 1, PID_NAK,
                   8, 0, 0, datain_toggle, ZLP);
   end
endtask
