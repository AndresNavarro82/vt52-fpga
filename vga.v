`include "led_counter.v"
`include "sync_generator.v"
`include "char_generator.v"
`include "cursor_blinker.v"
`include "cursor_position.v"

module top (
	    input       pclk,
	    input       clr, //asynchronous reset
	    output wire hsync,
	    output wire vsync,
	    output wire video,
	    output wire LED1,
	    output wire LED2,
            output wire LED3,
	    output wire LED4,
	    output wire LED5
            );

   // sync generator outputs
   wire [10:0]          hc;
   wire [10:0]          vc;
   wire                 vblank, hblank;
   wire                 px_clk;

   wire                 video_out;
   wire                 cursor_blink_on;

   wire [3:0] cursor_y;
   reg [3:0]  new_cursor_y;
   wire [5:0] cursor_x;
   reg [5:0]  new_cursor_x;
   reg        write_cursor_pos;

   reg [3:0] row;
   reg [5:0] col;
   wire      char_pixel;

   // TODO rewrite this instantiations to used the param names
   sync_generator mysync_generator(pclk, clr, hsync, vsync, hblank, vblank, hc, vc, px_clk);
   char_generator mychar_generator(px_clk, clr, hblank, vblank, row, col, char_pixel);
   led_counter myled_counter(vblank, {LED1, LED2, LED3, LED4, LED5});
   cursor_blinker mycursor_blinker(vblank, clr, cursor_blink_on);
   cursor_position #(.SIZE(6)) mycursor_x (px_clk, clr, new_cursor_x, write_cursor_pos, cursor_x);
   cursor_position #(.SIZE(4)) mycursor_y (px_clk, clr, new_cursor_y, write_cursor_pos, cursor_y);

   parameter video_on = 1'b1;
   localparam video_off = ~video_on;

   wire       is_under_cursor;
   assign is_under_cursor = (cursor_x == col) & (cursor_y == row);
   wire       cursor_pixel;
   // invert video when we are under the cursor & it's blinking
   assign cursor_pixel = is_under_cursor & cursor_blink_on;

   // only emit video on non-blanking, select pixel according to column
   assign video_out = char_pixel ^ cursor_pixel;
   assign video = (hblank || vblank)? video_off : video_out;

   // TODO refactor and move to new file
   always @(posedge px_clk or posedge clr)
     begin
	// reset condition
	if (clr == 1)
	  begin
             new_cursor_y <= 0;
             new_cursor_x <= 0;
             write_cursor_pos <= 0;
 	  end
        else
          begin
             // TODO allow cursor movement
             new_cursor_y <= 0;
             new_cursor_x <= 0;
             write_cursor_pos <= 0;
          end
     end
endmodule
