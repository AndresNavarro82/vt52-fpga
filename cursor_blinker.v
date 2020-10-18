/**
 * Cursor blinker (uses vblank as tick, blinks about once a second)
 */
module cursor_blinker
  (
   input clk,
   input clr,
   input tick,
   input reset,
   output wire blink_on
   );
   localparam BITS = 6;
   reg has_incremented;
   reg [BITS-1:0] counter;
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         counter <= 0;
         has_incremented <= 0;
      end
      else if (reset) begin
         counter <= 0;
         has_incremented <= tick;
      end
      else if (tick && !has_incremented) begin
         counter <= counter + 1;
         has_incremented <= 1;
      end
      else if (!tick && has_incremented) begin
         has_incremented <= 0;
      end
   end
   assign blink_on = ~counter[BITS-1];
endmodule
