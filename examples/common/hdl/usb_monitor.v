`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)

module usb_monitor
  (
   input usb_dp_i,
   input usb_dn_i
   );

`define MAX_BITS 128
`define MAX_BYTES (8*1024)
`define MAX_STRING 128

   integer errors;
   integer warnings;

   wire    dp_sense;
   wire    dn_sense;

`include "usb_rx_tasks.v"

   reg [3:0] pid;
   reg [6:0] addr;
   reg [3:0] endp;
   reg [10:0] frame;
   reg [8*`MAX_BYTES-1:0] data;
   reg [8*`MAX_STRING-1:0] info;

   integer                 bytes;

   assign dp_sense = usb_dp_i;
   assign dn_sense = usb_dn_i;

   initial begin
      errors = 0;
      warnings = 0;
      forever begin
         packet_rx(pid, addr, endp, frame, data, bytes,
                   `BIT_TIME, 1000000);
         case (pid)
           PID_OUT : info[8*(`MAX_STRING-3) +:8*3] = "OUT";
           PID_IN : info[8*(`MAX_STRING-2) +:8*2] = "IN";
           PID_SOF : info[8*(`MAX_STRING-3) +:8*3] = "SOF";
           PID_SETUP : info[8*(`MAX_STRING-5) +:8*5] = "SETUP";
           PID_DATA0 : info[8*(`MAX_STRING-5) +:8*5] = "DATA0";
           PID_DATA1 : info[8*(`MAX_STRING-5) +:8*5] = "DATA1";
           PID_ACK : info[8*(`MAX_STRING-3) +:8*3] = "ACK";
           PID_NAK : info[8*(`MAX_STRING-3) +:8*3] = "NAK";
           PID_STALL : info[8*(`MAX_STRING-4) +:8*4] = "STALL";
           default : ;
         endcase
      end
   end

endmodule
