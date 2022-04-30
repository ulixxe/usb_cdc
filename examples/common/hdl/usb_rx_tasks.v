`include "sim_tasks.v"

localparam [3:0] PID_OUT = 4'b0001,
                 PID_IN = 4'b1001,
                 PID_SOF = 4'b0101,
                 PID_SETUP = 4'b1101,
                 PID_DATA0 = 4'b0011,
                 PID_DATA1 = 4'b1011,
                 PID_ACK = 4'b0010,
                 PID_NAK = 4'b1010,
                 PID_STALL = 4'b1110;

function automatic [4:0] crc5;
   input [MAX_BITS-1:0] data;
   input integer        bits;
   localparam [4:0]     POLY5 = 5'b00101;
   integer              i;
   begin
      crc5 = 5'b11111;
      for (i = 0; i <= bits-1; i = i + 1) begin
         if ((data[i] ^ crc5[4]) == 1'b1)
           crc5 = {crc5[3:0], 1'b0} ^ POLY5;
         else
           crc5 = {crc5[3:0], 1'b0};
      end
   end
endfunction

function automatic [15:0] crc16;
   input [8*MAX_BYTES-1:0] data;
   input integer           bytes;
   localparam [15:0]       POLY16 = 16'h8005;
   integer                 i,j;
   begin
      crc16 = 16'hFFFF;
      for (j = bytes-1; j >= 0; j = j-1) begin
         for (i = 0; i <= 7; i = i+1) begin
            if ((data[8*j+i] ^ crc16[15]) == 1'b1)
              crc16 = {crc16[14:0], 1'b0} ^ POLY16;
            else
              crc16 = {crc16[14:0], 1'b0};
         end
      end
   end
endfunction

task automatic wait_bit
  (
   input time    bit_time,
   input integer timeout // number of bit_time periods
   );
   localparam real STABLE_RATIO = 0.5; // stable time / bit_time
   time            start_time;
   time            wait_time;
   reg             exit;

   begin : u_wait_bit_task
      start_time = $time;
      wait_time = bit_time;
      exit = 0;
      while (~exit) begin
         fork : u_fork
            begin
               #wait_time;
               exit = 1;
               disable u_fork;
            end
            begin
               @(dp_sense or dn_sense);
               wait_time = bit_time*STABLE_RATIO/2;
               if ($time-start_time > timeout*bit_time) begin
                  `report_error("wait_bit(): Data lines are instable")
                  exit = 1;
               end
               disable u_fork;
            end
         join
      end
   end
endtask

task automatic wait_idle
  (
   input time timeout
   );
   time       start_time;
   time       wait_time;
   reg        exit;

   begin : u_wait_idle_task
      start_time = $time;
      wait_time = timeout;
      exit = 0;
      while (~exit) begin
         fork : u_fork
            begin
               #wait_time;
               exit = 1;
               disable u_fork;
            end
            begin
               if (dp_sense === 1'b1 && dn_sense === 1'b0)
                 exit = 1;
               else
                 @(dp_sense or dn_sense);
               wait_time = timeout-($time-start_time);
               disable u_fork;
            end
         join
      end
   end
endtask

task automatic raw_packet_rx
  (
   output [8*MAX_BYTES-1:0] data,
   output integer           bytes,
   input time               bit_time,
   input integer            timeout // number of bit_time periods
   );
   time                     start_time;
   integer                  byte_index;
   integer                  bit_index;
   integer                  bit_counter;
   reg                      nrzi_bit;
   reg                      last_nrzi_bit;
   reg                      exit;

   begin : u_raw_packet_rx_task
      data = 'bX;
      bytes = 0;

      // sync pattern
      bit_counter = 0;
      last_nrzi_bit = 1'bX;
      exit = 1'b0;
      start_time = $time;
      while (~exit) begin
         wait_bit(bit_time, timeout);
         if ((dp_sense === 1'b1 && dn_sense === 1'b0) ||
             (dp_sense === 1'b0 && dn_sense === 1'b1)) begin
            nrzi_bit = dp_sense;
            if (bit_counter == 7 && nrzi_bit === 1'b0 && last_nrzi_bit === 1'b0)
              exit = 1'b1;
            else if (nrzi_bit === ~last_nrzi_bit)
              bit_counter = bit_counter + 1;
            else
              bit_counter = 0;
         end else
           bit_counter = 0;
         last_nrzi_bit = nrzi_bit;
         if (bit_counter > 20 || ($time-start_time > timeout*bit_time)) begin
            `report_error("raw_packet_rx(): timeout")
         end else if (bit_counter != 0)
           start_time = $time;
      end

      // data transmission
      bit_counter = 1;
      byte_index = MAX_BYTES-1;
      exit = 1'b0;
      while (byte_index >= -1 && exit == 1'b0) begin : u_byte
         bit_index = 0;
         while (bit_index < 8) begin : u_bit
            wait_bit(bit_time, timeout);
            if ((dp_sense === 1'b1 && dn_sense === 1'b0) ||
                (dp_sense === 1'b0 && dn_sense === 1'b1)) begin
               if (byte_index >= 0 || bit_counter == 6)
                 nrzi_bit = dp_sense;
               else begin
                  `report_error("raw_packet_rx(): Data overflow")
               end
            end else if (dp_sense === 1'b0 && dn_sense === 1'b0 && bit_index == 0) begin
               if (bit_counter == 6) begin
                  `report_error("raw_packet_rx(): Bit stuffing error (last toggle missing)")
               end
               bit_index = bit_index + 1;
               disable u_bit;
            end else if (dp_sense === 1'b0 && dn_sense === 1'b0 && bit_index == 1) begin
               exit = 1'b1;
               disable u_byte;
            end else begin
               `report_error("raw_packet_rx(): Not allowed data lines value")
            end
            if (nrzi_bit === last_nrzi_bit) begin
               if (bit_counter == 6) begin
                  `report_error("raw_packet_rx(): Bit stuffing error (7 bits at '1')")
               end
               data[8*byte_index+bit_index] = 1'b1;
               bit_index = bit_index + 1;
               bit_counter = bit_counter + 1;
            end else begin
               if (bit_counter != 6) begin
                  data[8*byte_index+bit_index] = 1'b0;
                  bit_index = bit_index + 1;
               end
               bit_counter = 0;
            end
            last_nrzi_bit = nrzi_bit;
         end
         byte_index = byte_index - 1;
         bytes = bytes + 1;
      end

      // End Of Packet
      wait_bit(bit_time, timeout);
      if (dp_sense !== 1'b1 || dn_sense !== 1'b0) begin
         `report_error("raw_packet_rx(): Eye timing violation on EOP")
      end
   end
endtask

task automatic packet_rx
  (
   output [3:0]             pid,
   output [6:0]             addr,
   output [3:0]             endp,
   output [10:0]            frame,
   output [8*MAX_BYTES-1:0] data,
   output integer           bytes,
   input time               bit_time,
   input integer            timeout // number of bit_time periods
   );
   localparam [4:0]         POLY5_RESIDUAL = 5'b01100;
   localparam [15:0]        POLY16_RESIDUAL = 16'b1000000000001101;
   reg [8*MAX_BYTES-1:0]    raw_data;
   integer                  raw_bytes;
   integer                  i;
   begin : u_packet_rx_task
      pid = 'bX;
      addr = 'bX;
      endp = 'bX;
      frame = 'bX;
      data = 'bX;
      bytes = 0;
      raw_packet_rx(raw_data, raw_bytes, bit_time, timeout);
      if (raw_data[8*(MAX_BYTES-1) +:4] == ~raw_data[8*(MAX_BYTES-1)+4 +:4]) begin
         pid = raw_data[8*(MAX_BYTES-1) +:4];
      end else begin
         `report_warning("packet_rx(): PID field check error")
         disable u_packet_rx_task;
      end
      case (pid)
        PID_OUT, PID_IN, PID_SOF, PID_SETUP : begin
           if (raw_bytes != 3) begin
              `report_warning("packet_rx(): Received bytes doesn't match Token Packet size")
              disable u_packet_rx_task;
           end else if (crc5({raw_data[8*(MAX_BYTES-3) +:8], raw_data[8*(MAX_BYTES-2) +:8]}, 16) == POLY5_RESIDUAL) begin
              if (pid == PID_SOF) begin
                 frame = {raw_data[8*(MAX_BYTES-3) +:3], raw_data[8*(MAX_BYTES-2) +:8]};
              end else begin
                 addr = raw_data[8*(MAX_BYTES-2) +:7];
                 endp = {raw_data[8*(MAX_BYTES-3) +:3], raw_data[8*(MAX_BYTES-2)+7]};
              end
           end else begin
              `report_warning("packet_rx(): token CRC error")
              disable u_packet_rx_task;
           end
        end
        PID_DATA0, PID_DATA1 : begin
           if (raw_bytes < 3) begin
              `report_warning("packet_rx(): Received bytes doesn't match Data Packet size")
              disable u_packet_rx_task;
           end else begin
              for (i = 1; i <= raw_bytes-1; i = i+1)
                data[8*(raw_bytes-1-i) +:8] = raw_data[8*(MAX_BYTES-1-i) +:8];
              if (crc16(data, raw_bytes-1) == POLY16_RESIDUAL) begin
                 bytes = raw_bytes-3;
                 data = 'bX;
                 for (i = 1; i <= raw_bytes-3; i = i+1)
                   data[8*(MAX_BYTES-i) +:8] = raw_data[8*(MAX_BYTES-1-i) +:8];
              end else begin
                 data = 'bX;
                 `report_warning("packet_rx(): CRC error")
                 disable u_packet_rx_task;
              end
           end
        end
        PID_ACK, PID_NAK, PID_STALL : begin
           if (raw_bytes != 1) begin
              `report_warning("packet_rx(): Received bytes doesn't match Handshake Packet size")
              disable u_packet_rx_task;
           end
        end
        default : begin
           `report_warning("packet_rx(): Packet not recognized")
           disable u_packet_rx_task;
        end
      endcase
   end
endtask

task automatic handshake_rx
  (
   output [3:0]  pid,
   input time    bit_time,
   input integer timeout // number of bit_time periods
   );
   reg [6:0]     addr;
   reg [3:0]     endp;
   reg [10:0]    frame;
   reg [8*MAX_BYTES-1:0] data;
   integer               bytes;
   begin : u_handshake_rx_task
      packet_rx(pid, addr, endp, frame, data, bytes,
                bit_time, timeout);
      if (pid != PID_ACK && pid != PID_NAK && pid != PID_STALL) begin
         `report_error("handshake_rx(): Missing Handshake Packet")
         disable u_handshake_rx_task;
      end
   end
endtask

task automatic data_rx
  (
   output [3:0]             pid,
   output [8*MAX_BYTES-1:0] data,
   output integer           bytes,
   input time               bit_time,
   input integer            timeout // number of bit_time periods
   );
   reg [6:0]                addr;
   reg [3:0]                endp;
   reg [10:0]               frame;
   begin : u_data_rx_task
      packet_rx(pid, addr, endp, frame, data, bytes,
                bit_time, timeout);
      if (pid != PID_DATA0 && pid != PID_DATA1) begin
         `report_error("data_rx(): Missing Data Packet")
         disable u_data_rx_task;
      end
   end
endtask
