
`define assert_error(msg, signal, value) \
   if ((signal) !== (value)) begin \
      errors = errors + 1; \
      $display("%c[1;31m",27); \
      $display("ERROR @ %t: %s", $time, msg); \
      $display("  actual:   %x", signal); \
      $display("  expected: %x", value); \
      $display("%c[0m",27); \
      #(1*`BIT_TIME); \
      $finish; \
  end

`define report_error(msg) \
   errors = errors + 1; \
   $display("%c[1;31m",27); \
   $display("ERROR @ %t\n  %s", $time, msg); \
   $display("%c[0m",27); \
   #(1*`BIT_TIME); \
   $finish;

`define assert_warning(msg, signal, value) \
   if ((signal) !== (value)) begin \
      warnings = warnings + 1; \
      $display("%c[1;31m",27); \
      $display("WARNING @ %t: %s", $time, msg); \
      $display("  actual:   %x", signal); \
      $display("  expected: %x", value); \
      $display("%c[0m",27); \
  end

`define report_warning(msg) \
   warnings = warnings + 1; \
   $display("%c[1;33m",27); \
   $display("WARNING @ %t\n  %s", $time, msg); \
   $display("%c[0m",27);

`define report_end(msg) \
   $display("%c[1;32m",27); \
   $display("@ %t\n  %s", $time, msg); \
   $display("%c[0m",27); \
   $finish;

`define progress_bar(end_ms) \
   integer time_ms; \
   initial begin \
      time_ms = 0; \
      forever begin \
         #(1000000/83*`BIT_TIME); \
         time_ms = time_ms + 1; \
         $write("%4d ms", time_ms); \
         if (end_ms > 0) \
            $write("  (%3d%%)", 100*time_ms/end_ms); \
         $write("\015"); \
         $fflush(32'h8000_0001); // flush STDOUT \
      end \
   end
