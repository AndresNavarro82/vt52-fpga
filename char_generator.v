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
    output reg hsync,
    output reg vsync,
    output reg hblank,
    output reg vblank,
    output reg [ROW_BITS-1:0] row,
    output reg [COL_BITS-1:0] col,
    output reg pixel_out,
    input [ADDR_BITS-1:0] buffer_waddr,
    input [7:0] buffer_din,
    input buffer_wen,
    input [ADDR_BITS-1:0] buffer_first_char,
    input buffer_first_char_wen
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
   // horizontal & vertical counters
   reg [hbits-1:0] hc, next_hc;
   reg [vbits-1:0] vc, next_vc;
   // character generation
   reg [ROW_BITS-1:0] next_row;
   reg [COL_BITS-1:0] next_col;
   // columns counts two for every real column because the clk is twice the pixel rate
   reg [3:0] colc, next_colc;
   reg [3:0] rowc, next_rowc;
   // here we make the real column index, accounting for the double rate and
   // the fact that the font has the order of the pixels mirrored
   wire [2:0] rcolc = colc[3:1];
   wire [2:0] col_index = 7 - rcolc;

   reg [ADDR_BITS-1:0] char, next_char;
   reg [7:0] char_row, next_char_row;
   wire [7:0] rom_char_row;

   reg hsync_flag, next_hsync_flag;

   reg [ADDR_BITS-1:0] first_char;

   // XXX for now we are constantly reading from both
   // rom & ram, we clock the row on the last column of the char
   // (or hblank)
   wire       buffer_ren = 1'b1;

   // The address of the char row is formed with the char and the row offset
   // we can get away with the addition here because we have a power of 2
   // number of rows (16 in this case)
   wire [7:0] char_address_high;
   char_buffer mychar_buffer(buffer_din, buffer_waddr, buffer_wen, clk, next_char, char_address_high, buffer_ren);
   wire [11:0] char_address = { char_address_high, rowc };
   char_rom mychar_rom(char_address, clk, rom_char_row);

   reg delayed_pixel;

   //
   // horizontal & vertical counters
   //
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         hc <= 0;
         vc <= 0;
      end
      else begin
         hc <= next_hc;
         vc <= next_vc;
      end
   end

   // next_hc & next_vc
   always @(*) begin
      if (hc == hpixels) begin
         next_hc = 0;
         next_vc = (vc == vlines)? 0 : vc + 1;
      end
      else begin
         next_hc = hc + 1;
         next_vc = vc;
      end
   end

   // syncs & blanks
   always @(posedge clk or posedge clr) begin
      if (clr) begin
         hsync <= hsync_off;
         vsync <= vsync_off;
         hblank <= 1;
         vblank <= 1;
      end
      else begin
         hsync <= (next_hc >= hbp + hvisible + hfp)? hsync_on : hsync_off;
         vsync <= (next_vc >= vbp + vvisible + vfp)? vsync_on : vsync_off;
         hblank <= (next_hc < hbp || next_hc >= hbp + hvisible);
         vblank <= (next_vc < vbp || next_vc >= vbp + vvisible);
      end
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
         hsync_flag <= 0;
         char_row <= 0;
         first_char <= 0;
      end
      else begin
         row <= next_row;
         col <= next_col;
         rowc <= next_rowc;
         colc <= next_colc;
         char <= next_char;
         hsync_flag <= next_hsync_flag;
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
         next_hsync_flag = 0;
         next_char_row = rom_char_row;
      end
      else if (hblank) begin
         // some nice defaults
         next_row = row;
         next_rowc = rowc;
         next_col = 0;
         next_colc = 0;
         next_char = char;
         next_hsync_flag = 0;
         next_char_row = rom_char_row;

         // only do this once per line
         if (hsync_flag == 1) begin
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
            end // else: !if(rowc == 15)
         end // if (hsync_flag == 1)
      end // if (hblank)
      else begin
         // some nice defaults
         next_row = row;
         next_rowc = rowc;
         next_col = col;
         next_colc = colc+1;
         next_char = char;
         next_hsync_flag = 1;
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
      end // else: !if(hblank)
   end // always @ (posedge clk or posedge clr)

   always @(posedge clk or posedge clr) begin
      if (clr) begin
         pixel_out <= 0;
         delayed_pixel <= 0;
      end
      else begin
         // delayed pixel is to compensate for the double rate clock
         // otherwise the pixel would be delayed half a pixel clock
         // select pixel according to column
         delayed_pixel <= next_char_row[col_index];
         pixel_out <= delayed_pixel;
      end
   end
endmodule
