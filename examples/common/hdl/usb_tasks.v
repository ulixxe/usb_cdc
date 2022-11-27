
`define max(a,b)((a) > (b) ? (a) : (b))
`define min(a,b)((a) < (b) ? (a) : (b))

`include "usb_rx_tasks.v"


localparam [7:0] REQ_GET_STATUS = 'd0,
                 REQ_CLEAR_FEATURE = 'd1,
                 REQ_RESERVED1 = 'd2,
                 REQ_SET_FEATURE = 'd3,
                 REQ_RESERVED2 = 'd4,
                 REQ_SET_ADDRESS = 'd5,
                 REQ_GET_DESCRIPTOR = 'd6,
                 REQ_SET_DESCRIPTOR = 'd7,
                 REQ_GET_CONFIGURATION = 'd8,
                 REQ_SET_CONFIGURATION = 'd9,
                 REQ_GET_INTERFACE = 'd10,
                 REQ_SET_INTERFACE = 'd11,
                 REQ_SYNCH_FRAME = 'd12,
                 REQ_SET_LINE_CODING = 'h20,
                 REQ_GET_LINE_CODING = 'h21,
                 REQ_SET_CONTROL_LINE_STATE = 'h22,
                 REQ_SEND_BREAK = 'h23;

localparam       CTRL_MAXPACKETSIZE = 'd8;
localparam [3:0] ENDP_CTRL = 'd0,
                 ENDP_BULK = 'd1,
                 ENDP_INT = 'd2;

localparam [8*'h12-1:0] DEV_DESCR = { // Standard Device Descriptor, USB2.0 9.6.1, page 261-263, Table 9-8
                                      8'h12, // bLength
                                      8'h01, // bDescriptorType (DEVICE)
                                      8'h00, // bcdUSB[0]
                                      8'h02, // bcdUSB[1] (2.00)
                                      8'h02, // bDeviceClass (Communications Device Class)
                                      8'h00, // bDeviceSubClass (specified at interface level)
                                      8'h00, // bDeviceProtocol (specified at interface level)
                                      CTRL_MAXPACKETSIZE[7:0], // bMaxPacketSize0
                                      VENDORID[7:0], // idVendor[0]
                                      VENDORID[15:8], // idVendor[1]
                                      PRODUCTID[7:0], // idProduct[0]
                                      PRODUCTID[15:8], // idProduct[1]
                                      8'h00, // bcdDevice[0]
                                      8'h01, // bcdDevice[1] (1.00)
                                      8'h00, // iManufacturer (no string)
                                      8'h00, // iProduct (no string)
                                      8'h00, // iSerialNumber (no string)
                                      8'h01}; // bNumConfigurations

localparam [8*'h43-1:0] CONF_DESCR = { // Standard Configuration Descriptor, USB2.0 9.6.3, page 264-266, Table 9-10
                                       8'h09, // bLength
                                       8'h02, // bDescriptorType (CONFIGURATION)
                                       8'h43, // wTotalLength[0]
                                       8'h00, // wTotalLength[1]
                                       8'h02, // bNumInterfaces
                                       8'h01, // bConfigurationValue
                                       8'h00, // iConfiguration (no string)
                                       8'h80, // bmAttributes (bus powered, no remote wakeup)
                                       8'h32, // bMaxPower (100mA)

                                       // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                       8'h09, // bLength
                                       8'h04, // bDescriptorType (INTERFACE)
                                       8'h00, // bInterfaceNumber
                                       8'h00, // bAlternateSetting
                                       8'h01, // bNumEndpoints
                                       8'h02, // bInterfaceClass (Communications Device Class)
                                       8'h02, // bInterfaceSubClass (Abstract Control Model)
                                       8'h01, // bInterfaceProtocol (AT Commands in ITU V.25ter)
                                       8'h00, // iInterface (no string)

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
                                       8'h00, // bMasterInterface
                                       8'h01, // bSlaveInterface0

                                       // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                       8'h07, // bLength
                                       8'h05, // bDescriptorType (ENDPOINT)
                                       {4'h8, ENDP_INT}, // bEndpointAddress (2 IN)
                                       8'h03, // bmAttributes (interrupt)
                                       8'h08, // wMaxPacketSize[0]
                                       8'h00, // wMaxPacketSize[1]
                                       8'hFF, // bInterval (255 ms)

                                       // Standard Interface Descriptor, USB2.0 9.6.5, page 267-269, Table 9-12
                                       8'h09, // bLength
                                       8'h04, // bDescriptorType (INTERFACE)
                                       8'h01, // bInterfaceNumber
                                       8'h00, // bAlternateSetting
                                       8'h02, // bNumEndpoints
                                       8'h0A, // bInterfaceClass (data)
                                       8'h00, // bInterfaceSubClass
                                       8'h00, // bInterfaceProtocol
                                       8'h00, // iInterface (no string)

                                       // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                       8'h07, // bLength
                                       8'h05, // bDescriptorType (ENDPOINT)
                                       {4'h0, ENDP_BULK}, // bEndpointAddress (1 OUT)
                                       8'h02, // bmAttributes (bulk)
                                       OUT_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                       8'h00, // wMaxPacketSize[1]
                                       8'h00, // bInterval

                                       // Standard Endpoint Descriptor, USB2.0 9.6.6, page 269-271, Table 9-13
                                       8'h07, // bLength
                                       8'h05, // bDescriptorType (ENDPOINT)
                                       {4'h8, ENDP_BULK}, // bEndpointAddress (1 IN)
                                       8'h02, // bmAttributes (bulk)
                                       IN_BULK_MAXPACKETSIZE[7:0], // wMaxPacketSize[0]
                                       8'h00, // wMaxPacketSize[1]
                                       8'h00}; // bInterval

`define rev(n) \
function automatic [n-1:0] rev``n;\
   input [n-1:0] data;\
   integer       i;\
   begin\
      for (i = 0; i <= n-1; i = i + 1) begin\
         rev``n[i] = data[n-1-i];\
               end\
   end\
endfunction

`rev(5)
`rev(8)
`rev(16)

task automatic raw_tx
  (
   input integer        length,
   input [MAX_BITS-1:0] dp_data,
   input [MAX_BITS-1:0] dn_data,
   input time           bit_time
   );
   integer              i;
   begin
      #bit_time;
      for (i = length-1; i >= 0; i = i-1) begin
         dp_force = dp_data[i];
         dn_force = dn_data[i];
         #bit_time;
      end
      dp_force = 1'bZ;
      dn_force = 1'bZ;
   end
endtask

task automatic nrzi_tx
  (
   input [8*MAX_BITS-1:0] nrzi_data,
   input time             bit_time
   );
   integer                i;
   begin
      #bit_time;
      for (i = MAX_BITS-1; i >= 0; i = i-1) begin
         if (nrzi_data[8*i +:8] == "J" || nrzi_data[8*i +:8] == "j") begin
            dp_force = 1'b1;
            dn_force = 1'b0;
            #bit_time;
         end else if (nrzi_data[8*i +:8] == "K" || nrzi_data[8*i +:8] == "k") begin
            dp_force = 1'b0;
            dn_force = 1'b1;
            #bit_time;
         end else if (nrzi_data[8*i +:8] == "0") begin
            dp_force = 1'b0;
            dn_force = 1'b0;
            #bit_time;
         end else if (nrzi_data[8*i +:8] == "1") begin
            dp_force = 1'b1;
            dn_force = 1'b1;
            #bit_time;
         end
      end
      dp_force = 1'bZ;
      dn_force = 1'bZ;
   end
endtask

task automatic usb_tx
  (
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input integer           sync_length,
   input time              bit_time
   );
   reg                     nrzi_bit;
   integer                 bit_counter;
   integer                 i,j;
   begin
      #bit_time;
      if (!(dp_sense === 1 && dn_sense === 0)) begin
         `report_error("usb_tx(): Data lines must be Idle before Start Of Packet")
      end

      // Start Of Packet and sync pattern
      nrzi_bit = 1;
      for (i = 1; i < sync_length; i = i+1) begin
         nrzi_bit = ~nrzi_bit;
         dp_force = nrzi_bit;
         dn_force = ~nrzi_bit;
         #bit_time;
      end
      bit_counter = 1;
      #bit_time;

      // data transmission
      for (j = bytes-1; j >= 0; j = j-1) begin
         for (i = 0; i < 8; i = i+1) begin
            if (data[8*j+i] == 0) begin
               nrzi_bit = ~nrzi_bit;
               bit_counter = 0;
            end else
              bit_counter = bit_counter + 1;
            dp_force = nrzi_bit;
            dn_force = ~nrzi_bit;
            #bit_time;
            if (bit_counter == 6) begin
               nrzi_bit = ~nrzi_bit;
               bit_counter = 0;
               dp_force = nrzi_bit;
               dn_force = ~nrzi_bit;
               #bit_time;
            end
         end
      end

      // End Of Packet
      dp_force = 0;
      dn_force = 0;
      #(2*bit_time); // USB 2.0 Table 7-2
      dp_force = 1;
      dn_force = 0;
      #bit_time;
      dp_force = 1'bZ;
      dn_force = 1'bZ;
   end
endtask

task automatic handshake_tx
  (
   input [3:0]   pid,
   input integer sync_length,
   input time    bit_time
   );
   begin
      usb_tx ({~pid, pid}, 1, sync_length, bit_time);
   end
endtask

task automatic token_tx
  (
   input [3:0]   pid,
   input [6:0]   addr,
   input [3:0]   endp,
   input integer sync_length,
   input time    bit_time
   );
   reg [4:0]     crc;
   begin
      crc = ~rev5(crc5({endp, addr}, 11));
      usb_tx ({~pid, pid, endp[0], addr, crc, endp[3:1]}, 3, sync_length, bit_time);
   end
endtask

task automatic sof_tx
  (
   input [10:0]  frame,
   input integer sync_length,
   input time    bit_time
   );
   reg [4:0]     crc;
   begin
      crc = ~rev5(crc5(frame, 11));
      usb_tx ({~PID_SOF, PID_SOF, frame[7:0], crc, frame[10:8]}, 3, sync_length, bit_time);
   end
endtask

task automatic data_tx
  (
   input [3:0]             pid,
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input integer           sync_length,
   input time              bit_time
   );
   reg [15:0]              crc;
   begin
      if (bytes > 0)
        crc = ~rev16(crc16(data, bytes));
      else
        crc = 16'h0000;
      if (bytes == MAX_BYTES)
        usb_tx ({~pid, pid, data, crc}, bytes+3, sync_length, bit_time);
      else begin
         data[8*bytes +:8] = {~pid, pid};
         usb_tx ({data, crc[7:0], crc[15:8]}, bytes+3, sync_length, bit_time);
      end
   end
endtask

task automatic zlp_tx
  (
   input [3:0]   pid,
   input integer sync_length,
   input time    bit_time
   );
   begin
      data_tx (pid, 'd0, 0, sync_length, bit_time);
   end
endtask

task automatic test_sof
  (
   input [10:0] frame,
   input [10:0] expected_frame
   );
   begin
      sof_tx(frame, 8, `BIT_TIME);
      #(4*`BIT_TIME);
      `assert_error("SOF packet", `USB_CDC_INST.u_sie.frame_o, expected_frame)
   end
endtask

task automatic test_sof_crc_error
  (
   input [10:0] expected_frame
   );
   begin
      usb_tx('hA50378, 3, 8, `BIT_TIME); // A50379 => frame=11'h103
      #(4*`BIT_TIME);
      `assert_error("test_sof_crc_error(): SOF packet accepted with CRC error", `USB_CDC_INST.u_sie.frame_o, expected_frame)
   end
endtask

task automatic test_data_out
  (
   input [6:0]             address,
   input [3:0]             endp,
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input [3:0]             rx_pid,
   input integer           wMaxPacketSize,
   input time              timeout,
   input time              wait_time, 
   inout [15:0]            dataout_toggle
   );
   localparam              PACKET_TIMEOUT = 6; // TRSPIPD1 (USB2.0 Tab.7-14 pag.188)
   reg                     zlp;
   reg [3:0]               packet_pid;
   time                    start_timeout;
   integer                 packet_bytes;
   integer                 i;
   begin : u_test_data_out_task
      start_timeout = $time;
      i = 0;
      zlp = (bytes == 0) ? 1'b1 : 1'b0;
      while (i < bytes || zlp == 1'b1) begin
         token_tx(PID_OUT, address, endp, 8, `BIT_TIME);
         packet_bytes = `min(wMaxPacketSize, bytes-i);
         data_tx(dataout_toggle[endp]? PID_DATA1: PID_DATA0,
                 data >> 8*(bytes-(i+packet_bytes)),
                 packet_bytes, 8, `BIT_TIME);
         handshake_rx(packet_pid, `BIT_TIME, PACKET_TIMEOUT);
         #(1*`BIT_TIME);
         if (packet_pid == PID_NAK) begin
            if ($time-start_timeout > timeout) begin
               `assert_error("test_data_out(): Device handshake PID error", packet_pid, rx_pid)
               disable u_test_data_out_task;
            end
            #(wait_time);
         end else if (packet_pid == PID_ACK) begin
            `assert_error("test_data_out(): Device handshake PID error", packet_pid, PID_ACK)
            dataout_toggle[endp] = ~dataout_toggle[endp];
            i = i + packet_bytes;
            zlp = 1'b0;
            start_timeout = $time;
         end else begin
            // device STALL
            `assert_error("test_data_out(): Device handshake PID error", packet_pid, rx_pid)
            disable u_test_data_out_task;
         end
      end
      `assert_error("test_data_out(): Device handshake PID error", packet_pid, rx_pid)
   end
endtask

localparam NO_ZLP = 0,
           ZLP = 1;

task automatic test_data_in
  (
   input [6:0]             address,
   input [3:0]             endp,
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input [3:0]             rx_pid,
   input integer           wMaxPacketSize,
   input time              timeout,
   input time              wait_time, 
   inout [15:0]            datain_toggle,
   input                   req_zlp
   );
   localparam              PACKET_TIMEOUT = 6; // TRSPIPD1 (USB2.0 Tab.7-14 pag.188)
   reg                     zlp;
   reg [3:0]               packet_pid;
   reg [6:0]               packet_addr;
   reg [3:0]               packet_endp;
   reg [10:0]              packet_frame;
   reg [8*MAX_BYTES-1:0]   packet_data;
   time                    start_timeout;
   integer                 packet_bytes;
   integer                 i;
   begin : u_test_data_in_task
      start_timeout = $time;
      i = 0;
      zlp = (bytes == 0) ? 1'b1 : 1'b0;
      while (i < bytes || zlp == 1'b1) begin
         token_tx(PID_IN, address, endp, 8, `BIT_TIME);
         packet_rx(packet_pid, packet_addr, packet_endp, packet_frame, packet_data, packet_bytes, `BIT_TIME, PACKET_TIMEOUT);
         #(1*`BIT_TIME);
         if (packet_pid == PID_DATA0 || packet_pid == PID_DATA1) begin
            // device DATAx
            `assert_error("test_data_in(): Device DATAx missing", packet_pid, datain_toggle[endp]? PID_DATA1: PID_DATA0)
            if (packet_bytes > 0) begin
               `assert_error("test_data_in(): Unexpected device data",
                             packet_data >> 8*`max(0, MAX_BYTES-packet_bytes),
                             ((data << 8*(MAX_BYTES-bytes+i)) >> 8*(MAX_BYTES-bytes+i)) >> 8*(bytes-(i+packet_bytes)))
            end else begin
               if (i != bytes) begin
                  `report_error("test_data_in(): Unexpected ZLP")
               end
            end
            handshake_tx(PID_ACK, 8, `BIT_TIME);
            datain_toggle[endp] = ~datain_toggle[endp];
            i = i + packet_bytes;
            zlp = (req_zlp == ZLP && i == bytes && packet_bytes == wMaxPacketSize) ? 1'b1 : 1'b0;
            start_timeout = $time;
         end else if (packet_pid == PID_NAK) begin
            if ($time-start_timeout > timeout) begin
               `assert_error("test_data_in(): Device PID error", packet_pid, rx_pid)
               disable u_test_data_in_task;
            end
            #(wait_time);
         end else begin
            // device STALL
            `assert_error("test_data_in(): Device PID error", packet_pid, rx_pid)
            disable u_test_data_in_task;
         end
      end
      if (rx_pid != PID_ACK && (packet_pid == PID_DATA0 || packet_pid == PID_DATA1)) begin
         `assert_error("test_data_in(): Device PID error", packet_pid, rx_pid)
         disable u_test_data_in_task;
      end
   end
endtask

task automatic test_setup_transaction
  (
   input [6:0]  address,
   input [7:0]  bmRequestType,
   input [7:0]  bRequest,
   input [15:0] wValue,
   input [15:0] wIndex,
   input [15:0] wLength,
   inout [15:0] datain_toggle,
   inout [15:0] dataout_toggle
   );
   localparam   PACKET_TIMEOUT = 6; // TRSPIPD1 (USB2.0 Tab.7-14 pag.188)
   reg [3:0]    pid;
   begin : u_test_setup_transaction_task
      token_tx(PID_SETUP, address, ENDP_CTRL, 8, `BIT_TIME);
      dataout_toggle = 'd0;
      datain_toggle = 'd0;
      datain_toggle[ENDP_CTRL] = ~datain_toggle[ENDP_CTRL];
      data_tx(dataout_toggle[ENDP_CTRL]? PID_DATA1: PID_DATA0,
              {bmRequestType, bRequest, {wValue[7:0], wValue[15:8]}, {wIndex[7:0], wIndex[15:8]}, {wLength[7:0], wLength[15:8]}},
              8, 8, `BIT_TIME);
      // device ACK
      handshake_rx(pid, `BIT_TIME, PACKET_TIMEOUT);
      #(1*`BIT_TIME);
      `assert_error("test_setup_transaction(): Device ACK missing", pid, PID_ACK)
      dataout_toggle[ENDP_CTRL] = ~dataout_toggle[ENDP_CTRL];
   end
endtask

localparam NO_STALL = 0,
           STALL = 1;

task automatic test_setup_in
  (
   input [6:0]             address,
   input [7:0]             bmRequestType,
   input [7:0]             bRequest,
   input [15:0]            wValue,
   input [15:0]            wIndex,
   input [15:0]            wLength,
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input                   device_stall
   );
   localparam              PACKET_TIMEOUT = 6; // TRSPIPD1 (USB2.0 Tab.7-14 pag.188)
   reg [3:0]               pid;
   reg [15:0]              datain_toggle;
   reg [15:0]              dataout_toggle;
   reg [8*MAX_BYTES-1:0]   device_data;
   integer                 device_bytes;
   begin : u_test_setup_in_task
      test_setup_transaction(address, bmRequestType, bRequest, wValue, wIndex, wLength, datain_toggle, dataout_toggle);
      test_data_in(address, ENDP_CTRL, data, bytes, device_stall ? PID_STALL : PID_ACK,
                   CTRL_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, NO_ZLP);
      if (~device_stall) begin
         token_tx(PID_OUT, address, ENDP_CTRL, 8, `BIT_TIME);
         zlp_tx(dataout_toggle[ENDP_CTRL]? PID_DATA1: PID_DATA0, 8, `BIT_TIME);
         // device ACK
         handshake_rx(pid, `BIT_TIME, PACKET_TIMEOUT);
         #(1*`BIT_TIME);
         `assert_error("test_setup_in(): Device ACK missing", pid, PID_ACK)
      end
   end
endtask

task automatic test_setup_out
  (
   input [6:0]             address,
   input [7:0]             bmRequestType,
   input [7:0]             bRequest,
   input [15:0]            wValue,
   input [15:0]            wIndex,
   input [15:0]            wLength,
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input                   device_stall
   );
   localparam              PACKET_TIMEOUT = 6; // TRSPIPD1 (USB2.0 Tab.7-14 pag.188)
   reg [3:0]               pid;
   reg [15:0]              datain_toggle;
   reg [15:0]              dataout_toggle;
   reg [8*MAX_BYTES-1:0]   device_data;
   integer                 device_bytes;
   begin : u_test_setup_out_task
      test_setup_transaction(address, bmRequestType, bRequest, wValue, wIndex, wLength, datain_toggle, dataout_toggle);
      if (bytes > 0)
        test_data_out(address, ENDP_CTRL, data, bytes, PID_ACK,
                      CTRL_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);
      token_tx(PID_IN, address, ENDP_CTRL, 8, `BIT_TIME);
      if (device_stall) begin
         // device STALL
         handshake_rx(pid, `BIT_TIME, PACKET_TIMEOUT);
         #(1*`BIT_TIME);
         `assert_error("test_setup_out(): Device STALL missing", pid, PID_STALL)
         disable u_test_setup_out_task;
      end else begin
         // device DATA1
         data_rx(pid, device_data, device_bytes, `BIT_TIME, PACKET_TIMEOUT);
         #(1*`BIT_TIME);
         `assert_error("test_setup_out(): Device DATAx missing", pid, datain_toggle[ENDP_CTRL]? PID_DATA1: PID_DATA0)
         `assert_error("test_setup_out(): Unexpected device data", device_bytes, 'd0)
         handshake_tx(PID_ACK, 8, `BIT_TIME);
      end
   end
endtask

task automatic test_set_address
  (
   input [6:0] new_address,
   inout [6:0] address
   );
   begin
      test_setup_out(address, 8'h00, REQ_SET_ADDRESS, new_address, 16'h0000, 16'h0000,
                     8'd0, 0, NO_STALL);
      #(10*`BIT_TIME);
      address = new_address;
      test_setup_in(address, 8'h80, REQ_GET_CONFIGURATION, 16'h0000, 16'h0000, 16'h0001,
                    8'd0, 1, NO_STALL);
   end
endtask

task automatic test_usb_reset
  (
   inout [6:0] address
   );
   begin
      dp_force = 1'b0;
      dn_force = 1'b0;
      #(10000/83*`BIT_TIME); // TDETRST (USB2.0 Tab.7-14 pag.188)
      dp_force = 1'bZ;
      dn_force = 1'bZ;
      #(1*`BIT_TIME);
      address = 'd0;
      //      `assert_error("test_usb_reset(): Device address error", `USB_CDC_INST.u_ctrl_endp.addr_o, address)
      //      `assert_error("test_usb_reset(): Device state error", `USB_CDC_INST.u_ctrl_endp.dev_state_qq, DEFAULT_STATE)
   end
endtask

task automatic test_poweron_reset
  (
   inout [6:0] address
   );
   begin
      power_on = 1'b0;
      #(10000/83*`BIT_TIME);
      power_on = 1'b1;
      #(20000000/83*`BIT_TIME);
      address = 'd0;
      //      `assert_error("test_poweron_reset(): Device address error", `USB_CDC_INST.u_ctrl_endp.addr_o, address)
      //      `assert_error("test_poweron_reset(): Device state error", `USB_CDC_INST.u_ctrl_endp.dev_state_qq, POWERED_STATE)
   end
endtask

task automatic test_set_configuration
  (
   inout [6:0] address
   );
   begin
      test_setup_out(address, 8'h00, REQ_SET_CONFIGURATION, 16'h0001, 16'h0000, 16'h0000,
                     8'd0, 0, NO_STALL);
      #(10*`BIT_TIME);
      test_setup_in(address, 8'h80, REQ_GET_CONFIGURATION, 16'h0000, 16'h0000, 16'h0001,
                    8'd1, 1, NO_STALL);
   end
endtask

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
      test_setup_in(address, 8'h80, REQ_GET_DESCRIPTOR, 16'h0100, 16'h0000, 16'h0040,
                    DEV_DESCR, 'h12, NO_STALL);

      test = "GET_DESCRIPTOR Device (partial)";
      test_setup_in(address, 8'h80, REQ_GET_DESCRIPTOR, 16'h0100, 16'h0000, 16'h0008,
                    DEV_DESCR>>8*('h12-'h08), 'h08, NO_STALL);

      test = "GET_STATUS Error in Default state";
      test_setup_in(address, 8'h80, REQ_GET_STATUS, 16'h0000, 16'h0000, 16'h0002,
                    {8'h00, 8'h00}, 'h02, STALL);

      test = "SET_ADDRESS";
      test_set_address('d2, address);

      test = "GET_STATUS";
      test_setup_in(address, 8'h80, REQ_GET_STATUS, 16'h0000, 16'h0000, 16'h0002,
                    {8'h00, 8'h00}, 'h02, NO_STALL);

      test = "CLEAR_FEATURE";
      test_setup_out(address, 8'h02, REQ_CLEAR_FEATURE, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 'd0, NO_STALL);

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
      test_setup_in(address, 8'h80, REQ_GET_DESCRIPTOR, 16'h0200, 16'h0000, 16'h00FF,
                    CONF_DESCR, 'h43, NO_STALL);

      test = "GET_DESCRIPTOR String not supported";
      test_setup_in(address, 8'h80, REQ_GET_DESCRIPTOR, 16'h0300, 16'h0000, 16'h00FF,
                    8'd0, 'h8, STALL);

      test = "SET_CONFIGURATION";
      test_set_configuration(address);

      test = "GET_LINE_CODING";
      test_setup_in(address, 8'hA1, REQ_GET_LINE_CODING, 16'h0000, 16'h0000, 16'h0007,
                    {7{8'd0}}, 7, NO_STALL);

      test = "SET_LINE_CODING";
      test_setup_out(address, 8'h21, REQ_SET_LINE_CODING, 16'h0000, 16'h0000, 16'h0007,
                     {7{8'd0}}, 7, NO_STALL);

      test = "SET_CONTROL_LINE_STATE";
      test_setup_out(address, 8'h21, REQ_SET_CONTROL_LINE_STATE, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 0, NO_STALL);

      test = "SEND_BREAK";
      test_setup_out(address, 8'h21, REQ_SEND_BREAK, 16'h0000, 16'h0000, 16'h0000,
                     8'd0, 0, NO_STALL);

      test = "GET_INTERFACE";
      test_setup_in(address, 8'h81, REQ_GET_INTERFACE, 16'h0000, 16'h0001, 16'h0001,
                    8'd0, 1, NO_STALL);

      test = "SET_INTERFACE not supported";
      test_setup_out(address, 8'h01, REQ_SET_INTERFACE, 16'h0001, 16'h0001, 16'h0000,
                     8'd0, 0, STALL);

      test = "IN INT DATA";
      test_data_in(address, ENDP_INT, 8'd0, 1, PID_NAK,
                   8, 0, 0, datain_toggle, ZLP);
   end
endtask
