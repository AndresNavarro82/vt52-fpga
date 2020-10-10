module top (
            input       clk, // 16Mhz clock
            input       clr, // asynchronous reset
            output wire hsync,
            output wire vsync,
            output wire video,
            output wire led,
            input       ps2_data,
            input       ps2_clk,
            inout       pin_usb_p,
            inout       pin_usb_n,
            output      pin_pu
            );

   // pll outputs
   wire locked;
   wire fast_clk;
   // sync generator outputs
   wire [10:0]          hc;
   wire [10:0]          vc;
   wire                 vblank, hblank;
   wire                 px_clk;

   // cursor
   wire                 cursor_blink_on;
   wire [3:0] cursor_y;
   wire [5:0] cursor_x;
   // to allow modifications
   wire [3:0]  new_cursor_y = 0;
   wire [5:0]  new_cursor_x = 0;
   wire write_cursor_pos = 0;

   // char generator outputs
   wire [3:0] row;
   wire [5:0] col;
   wire      char_pixel;
   // char buffer inputs
   wire [7:0] new_char = 1;
   // we can do this because width is a power of 2 (2^6 = 64)
   wire [9:0] new_char_address;
   assign new_char_address = {cursor_y, cursor_x};
   wire  new_char_wen = 0;

   // USB
   // XXX/TODO use this for for all clears???
   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   wire      reset = ~reset_cnt[5];
   always @(posedge fast_clk)
     if ( locked )
       reset_cnt <= reset_cnt + reset;

   // uart pipeline in
   wire [7:0] uart_out_data;
   wire       uart_out_valid;
   wire       uart_out_ready = 0;

   wire [7:0] uart_in_data;
   wire       uart_in_valid;
   wire       uart_in_ready;

   // TODO rewrite this instantiations to used the param names
   pll mypll(clk, fast_clk, locked);
   sync_generator mysync_generator(fast_clk, clr, hsync, vsync, hblank, vblank, hc, vc, px_clk);
   char_generator mychar_generator(px_clk, clr, hblank, vblank, row, col, char_pixel,
                                   new_char_address, new_char, new_char_wen);
   led_counter myled_counter(vblank, led);
   cursor_blinker mycursor_blinker(vblank, clr, write_cursor_pos, cursor_blink_on);
   cursor_position #(.SIZE(6)) mycursor_x (px_clk, clr, new_cursor_x, write_cursor_pos, cursor_x);
   cursor_position #(.SIZE(4)) mycursor_y (px_clk, clr, new_cursor_y, write_cursor_pos, cursor_y);
   keyboard mykeyboard (fast_clk, clr, ps2_data, ps2_clk, uart_in_data, uart_in_valid,
                        uart_in_ready);

   // usb uart - this instanciates the entire USB device.
   usb_uart uart (
                  .clk_48mhz  (fast_clk),
                  .reset      (reset),

                  // pins
                  .pin_usb_p( pin_usb_p ),
                  .pin_usb_n( pin_usb_n ),

                  // uart pipeline in (from keyboard)
                  .uart_in_data( uart_in_data ),
                  .uart_in_valid( uart_in_valid ),
                  .uart_in_ready( uart_in_ready ),
                  // uart pipeline out (process->screen)
                  .uart_out_data( uart_out_data ),
                  .uart_out_valid( uart_out_valid ),
                  .uart_out_ready( uart_out_ready  )

                  );

   // USB host detect
   assign pin_pu = 1'b1;

   // Now we just need to combine the chars & the cursor
   parameter video_on = 1'b1;
   localparam video_off = ~video_on;

   wire video_out;
   wire is_under_cursor;
   wire cursor_pixel;

   assign is_under_cursor = (cursor_x == col) & (cursor_y == row);
   // invert video when we are under the cursor (if it's blinking)
   assign cursor_pixel = is_under_cursor & cursor_blink_on;
   assign video_out = char_pixel ^ cursor_pixel;
   // only emit video on non-blanking periods
   assign video = (hblank || vblank)? video_off : video_out;
endmodule
