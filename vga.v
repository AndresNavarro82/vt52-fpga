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
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // pll outputs
   wire locked;
   wire fast_clk;
   // sync generator outputs
   wire vblank, hblank;

   // cursor
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   // to allow modifications
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;

   // char generator outputs
   wire [ROW_BITS-1:0] row;
   wire [COL_BITS-1:0] col;
   wire char_pixel;
   // char buffer inputs
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;

   // USB
   // XXX/TODO use this for for all clears???
   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   wire reset = ~reset_cnt[5];
   always @(posedge fast_clk)
     if ( locked )
       reset_cnt <= reset_cnt + reset;

   // uart pipeline in
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;

   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;

   // TODO rewrite these instantiations to use the param names
   pll mypll(clk, fast_clk, locked);
   // TODO pass COLUMNS & ROWS PARAMS
   char_generator mychar_generator(fast_clk, clr, hsync, vsync, hblank, vblank,
                                   row, col, char_pixel,
                                   new_char_address, new_char, new_char_wen,
                                   new_first_char, new_first_char_wen);
   cursor_blinker mycursor_blinker(fast_clk, clr, vblank, new_cursor_wen, cursor_blink_on);
   cursor_position #(.SIZE(7)) mycursor_x (fast_clk, clr, new_cursor_x, new_cursor_wen, cursor_x);
   cursor_position #(.SIZE(5)) mycursor_y (fast_clk, clr, new_cursor_y, new_cursor_wen, cursor_y);
   keyboard mykeyboard (fast_clk, clr, ps2_data, ps2_clk, uart_in_data, uart_in_valid,
                        uart_in_ready);
   command_handler mycommand_handler (fast_clk, reset, uart_out_data, uart_out_valid,
                                      uart_out_ready, new_char, new_char_address, new_char_wen,
                                      new_cursor_x, new_cursor_y, new_cursor_wen,
                                      new_first_char, new_first_char_wen);

   // usb uart - this instantiates the entire USB device.
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
   // use led to show cursor rate
   assign led = cursor_blink_on;

 endmodule
