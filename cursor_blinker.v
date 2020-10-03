/**
 * Cursor blinker (used vblank as clock, blinks about once a second)
 */
module cursor_blinker (clk, clr, blink_on);
   input clk;
   input clr;
   output wire blink_on;
   reg [5:0] counter;

   always @(posedge clk or posedge clr)
     begin
	if (clr)
          counter <= 0;
	else
          counter <= counter + 1;
     end

   assign blink_on = counter[5];
 endmodule
