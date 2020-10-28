module top (input       clk,
            output wire hsync,
            output wire vsync,
            output wire video,
            output wire led,
            input       ps2_data,
            input       ps2_clk,
            inout       pin_usb_p,
            inout       pin_usb_n,
            output wire pin_pu
            );
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // pll outputs
   wire locked;
   wire clk_usb;
   wire clk_vga;

   // scroll
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [ADDR_BITS-1:0] first_char;
   // cursor
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   // char buffer
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [ADDR_BITS-1:0] char_address;
   wire [7:0] char;
   // XXX for now we are constantly reading from both
   // rom & ram, we clock the row on the last column of the char
   // (or hblank)
   wire buffer_ren = 1'b1;
   // char rom
   wire [11:0] char_rom_address;
   wire [7:0] char_rom_data;

   // video generator
   wire vblank, hblank;

   // led follows the cursor blink
   assign led = cursor_blink_on;

   // USB
   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   wire reset_usb = ~reset_cnt[5];
   always @(posedge clk_usb)
     if ( locked )
       reset_cnt <= reset_cnt + reset_usb;

   // we can use this directly because it's already sync'ed to the vga clock
   wire reset_vga;
   assign reset_vga = reset_usb;
   // divide by two
   reg vga_clk_divider;
   always @(posedge clk_usb) begin
      if (reset_usb) vga_clk_divider <= 0;
      else vga_clk_divider <= ~vga_clk_divider;
   end
   assign clk_vga = vga_clk_divider;

   // USB host detect
   assign pin_pu = 1'b1;

   // uart input/output
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;

   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;

   //
   // Instantiate all modules
   //
   // TODO rewrite these instantiations to use the param names
   pll pll(clk, clk_usb, locked);
   // They keyboard can use the usb clock as it only interacts with the usb uart
   keyboard keyboard(clk_usb, reset_usb, ps2_data, ps2_clk,
                     uart_in_data, uart_in_valid, uart_in_ready
                     );
   // TODO pass the cursor bits parameter
   cursor cursor(clk_usb, reset_usb, vblank, cursor_x, cursor_y, cursor_blink_on,
                 new_cursor_x, new_cursor_y, new_cursor_wen
                 );
   simple_register #(.SIZE(ADDR_BITS)) scroll_register(clk_usb, reset_usb, new_first_char,
                                                       new_first_char_wen, first_char);
   char_buffer char_buffer(new_char, new_char_address, new_char_wen, clk_usb,
                           char_address, char, buffer_ren);
   char_rom char_rom(char_rom_address, clk_usb, char_rom_data);
   // TODO pass COLUMNS & ROWS PARAMS
   video_generator video_generator(clk_vga, reset_vga,
                                   hsync, vsync, video, hblank, vblank,
                                   cursor_x, cursor_y, cursor_blink_on,
                                   first_char,
                                   char_address, char,
                                   char_rom_address, char_rom_data
                                   );
   usb_uart uart(.clk_48mhz(clk_usb),
                 .reset(reset_usb),
                 // usb pins
                 .pin_usb_p(pin_usb_p),
                 .pin_usb_n(pin_usb_n),
                 // uart pipeline in (keyboard->usb)
                 .uart_in_data(uart_in_data),
                 .uart_in_valid(uart_in_valid),
                 .uart_in_ready(uart_in_ready),
                 // uart pipeline out (usb->command_handler)
                 .uart_out_data(uart_out_data),
                 .uart_out_valid(uart_out_valid),
                 .uart_out_ready(uart_out_ready)
                 );

   command_handler command_handler(clk_usb, reset_usb,
                                   uart_out_data, uart_out_valid, uart_out_ready,
                                   new_first_char, new_first_char_wen,
                                   new_char, new_char_address, new_char_wen,
                                   new_cursor_x, new_cursor_y, new_cursor_wen);

 endmodule
