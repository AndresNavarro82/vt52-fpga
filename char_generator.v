/**
 * 80x24 char generator (8x16 char size) & sync generator
 * The pixel clock is half the clk input
 */
module char_generator
  #(parameter ROWS = 24,
    parameter COLS = 80,
    // XXX These could probably be calculated from the above
    parameter ROW_BITS = 5,
    parameter COL_BITS = 7,
    parameter ADDR_BITS = 11,
    // first address outside the visible area
    parameter PAST_LAST_ROW = ROWS * COLS
    )
   (input clk,
    input clr,
    // video output
    output reg hsync,
    output reg vsync,
    output reg video,
    // video output extra info
    output reg hblank,
    output reg vblank,
    output reg led,
    // scrolling
    input [ADDR_BITS-1:0] buffer_first_char,
    input buffer_first_char_wen,
    // char buffer write
    input [ADDR_BITS-1:0] buffer_waddr,
    input [7:0] buffer_din,
    input buffer_wen,
    // cursor
    input [COL_BITS-1:0] new_cursor_x,
    input [ROW_BITS-1:0] new_cursor_y,
    input new_cursor_wen
    );
   // VGA Signal 640x400 @ 70 Hz timing
   // from http://tinyvga.com/vga-timing/640x400@70Hz
   // Total size, visible size, front and back porches and sync pulse size
   // clk is 48Mhz (because USB...), so about twice what we need (around 25Mhz)
   // Every horizontal value is multiplied by two because we have a clock
   // that runs at twice the pixel rate
   localparam hbits = 12;
   localparam hpixels = 2*800;
   localparam hbp = 2*48;
   localparam hvisible = 2*640;
   localparam hfp = 2*16;
   localparam hpulse = 2*96;
   // Added 8 to vbp and vfp to compensate for the missing character row
   // (25 * 16pixels == 400, we are using 24 rows so we are 16 pixels short)
   localparam vbits = 12;
   localparam vlines = 449;
   localparam vbp = 35 + 8;
   localparam vvisible = 400 - 16;
   localparam vfp = 12 + 8;
   localparam vpulse = 2;
   // sync polarity
   localparam hsync_on = 1'b0;
   localparam vsync_on = 1'b1;
   localparam hsync_off = ~hsync_on;
   localparam vsync_off = ~vsync_on;
   // video polarity
   localparam video_on = 1'b1;
   localparam video_off = ~video_on;

   // These are to combine the chars & the cursor for video output
   reg is_under_cursor;
   reg cursor_pixel;
   reg [2:0] col_index;
   reg char_pixel;
   reg combined_pixel;

   // horizontal & vertical counters
   reg [hbits-1:0] hc, next_hc;
   reg [vbits-1:0] vc, next_vc;
   // syncs and blanks
   reg next_hblank, next_vblank, next_hsync, next_vsync;
   // character generation
   reg [ROW_BITS-1:0] row, next_row;
   reg [COL_BITS-1:0] col, next_col;
   // columns counts two for every real column because the clk is twice the pixel rate
   reg [3:0] colc, next_colc;
   reg [3:0] rowc, next_rowc;
   // here we make the real column index, accounting for the double rate and
   // the fact that the font has the order of the pixels mirrored
   wire [2:0] rcolc = colc[3:1];

   reg [ADDR_BITS-1:0] char, next_char;
   reg [7:0] char_row, next_char_row;
   wire [7:0] rom_char_row;

   reg [ADDR_BITS-1:0] first_char;

   // XXX for now we are constantly reading from both
   // rom & ram, we clock the row on the last column of the char
   // (or hblank)
   wire       buffer_ren = 1'b1;

   // The address of the char row is formed with the char and the row offset
   // we can get away with the addition here because we have a power of 2
   // number of rows (16 in this case)
   wire [7:0] char_address_high;
   char_buffer mychar_buffer(buffer_din, buffer_waddr, buffer_wen, clk,
                             next_char, char_address_high, buffer_ren);
   wire [11:0] char_address = { char_address_high, rowc };
   char_rom mychar_rom(char_address, clk, rom_char_row);

   //
   // cursor
   //
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   cursor_blinker mycursor_blinker(clk, clr, vblank, new_cursor_wen, cursor_blink_on);
   cursor_position #(.SIZE(7)) mycursor_x (clk, clr, new_cursor_x, new_cursor_wen, cursor_x);
   cursor_position #(.SIZE(5)) mycursor_y (clk, clr, new_cursor_y, new_cursor_wen, cursor_y);

   //
   // horizontal & vertical counters, syncs and blanks
   //
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         hc <= 0;
         vc <= 0;
         hsync <= hsync_off;
         vsync <= vsync_off;
         hblank <= 1;
         vblank <= 1;
      end
      else begin
         hc <= next_hc;
         vc <= next_vc;
         hsync <= next_hsync;
         vsync <= next_vsync;
         hblank <= next_hblank;
         vblank <= next_vblank;
      end
   end

   always @(*) begin
      if (hc == hpixels) begin
         next_hc = 0;
         next_vc = (vc == vlines)? 0 : vc + 1;
      end
      else begin
         next_hc = hc + 1;
         next_vc = vc;
      end
      next_hsync = (next_hc >= hbp + hvisible + hfp)? hsync_on : hsync_off;
      next_vsync = (next_vc >= vbp + vvisible + vfp)? vsync_on : vsync_off;
      next_hblank = (next_hc < hbp || next_hc >= hbp + hvisible);
      next_vblank = (next_vc < vbp || next_vc >= vbp + vvisible);
   end

   //
   // character generation
   //
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         row <= 0;
         col <= 0;
         rowc <= 0;
         colc <= 0;
         char <= 0;
         char_row <= 0;
         first_char <= 0;
      end
      else begin
         row <= next_row;
         col <= next_col;
         rowc <= next_rowc;
         colc <= next_colc;
         char <= next_char;
         char_row <= next_char_row;
         if (buffer_first_char_wen) begin
            first_char <= buffer_first_char;
         end
      end // else: !if(clr == 1)
   end // always @ (posedge clk or posedge clr)

   always @(*) begin
      if (vblank) begin
         next_row = 0;
         next_rowc = 0;
         next_col = 0;
         next_colc = 0;
         next_char = first_char;
         next_char_row = rom_char_row;
      end
      // we need next_hblank here because we must detect the edge
      // in hblank & prepare for the row
      else if (next_hblank) begin
         // some nice defaults
         next_row = row;
         next_rowc = rowc;
         next_col = 0;
         next_colc = 0;
         next_char = char;
         next_char_row = rom_char_row;

         // only do this once per line (positive hblank edge)
         if (hblank == 0) begin
            if (rowc == 15) begin
               // we are moving to the next row, so char
               // is already set at the correct value, unless
               // we reached the end of the buffer
               next_row = row + 1;
               next_rowc = 0;
               if (char == PAST_LAST_ROW) begin
                  next_char = 0;
               end
            end
            else begin
               // we are still on the same row, so
               // go back to the first char in this line
               next_char = char - COLS;
               next_rowc = rowc + 1;
            end
         end
      end
      else begin
         // some nice defaults
         next_row = row;
         next_rowc = rowc;
         next_col = col;
         next_colc = colc+1;
         next_char = char;
         next_char_row = char_row;

         if (colc == 0) begin
            // read the next char from mem as soon as possible
            next_char = char+1;
         end
         else if (colc == 15) begin
            // move to the next char
            next_col = col+1;
            next_colc = 0;
            next_char_row = rom_char_row;
         end
      end // else: !if(next_hblank)
   end // always @ (posedge clk or posedge clr)

   //
   // pixel out (char & cursor combination) & led (cursor blink)
   //
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         video <= video_off;
         led <= 0;
      end
      else begin
         video <= combined_pixel;
         led <= cursor_blink_on;
      end
   end

   always @(*) begin
      // cursor pixel: invert video when we are under the cursor (if it's blinking)
      is_under_cursor = (cursor_x == col) & (cursor_y == row);
      cursor_pixel = is_under_cursor & cursor_blink_on;
      // char pixel: read from the appropiate char, row & col on the font ROM
      col_index = 7 - rcolc;
      char_pixel = next_char_row[col_index];
      // combine, but only emit video on non-blanking periods
      combined_pixel = (next_hblank || next_vblank)?
                       video_off :
                       char_pixel ^ cursor_pixel;
   end
endmodule
