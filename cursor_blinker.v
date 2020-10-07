/**
 * Cursor blinker (used vblank as clock, blinks about once a second)
 */
module cursor_blinker (clk, clr, reset, blink_on);
   input clk;
   input clr;
   input reset; // synchronous reset for when the cursor pos is modified
   output wire blink_on;
   reg [5:0] counter;

   always @(posedge clk or posedge clr)
     begin
	if (clr)
          counter <= 0;
	else if (reset) // XXX this won't work unless we also use the pixel clock
          counter <= 0;
        else
          counter <= counter + 1;
     end

   assign blink_on = ~counter[5];
 endmodule
