/**
 * 64x16 char generator (8x16 char size)
 * TODO maybe this could use more of the sync generator output
 * instead of counting again here
 * TODO add inputs to write to char buffer
 */
module char_generator (
		       input            clk, // pixel clock
                       input            clr, // async reset
		       input            hblank,
		       input            vblank,
                       output reg [3:0] row,
                       output reg [5:0] col,
                       output reg       pixel_out
		       );

   reg [3:0] next_row;
   reg [5:0] next_col;
   reg [2:0] colc, next_colc;
   reg [3:0] rowc, next_rowc;

   reg [9:0] char, next_char;
   reg [7:0] char_row, next_char_row, rom_char_row;

   reg hsync_flag, next_hsync_flag;

   // write function not used for now
   wire [7:0] buffer_din = 8'b0;
   wire [9:0] buffer_waddr = 10'b0;
   wire       buffer_wen = 1'b0;
   // XXX for now we are constantly reading from both
   // rom & ram, we clock the row on the last column of the char
   // (or hblank)
   wire       buffer_ren = 1'b1;

   // The address of the char row is formed with the char and the row offset
   // we can get away with the addition here because we have a power of 2
   // number of columns
   wire [7:0] char_address_high;
   char_buffer mychar_buffer(buffer_din, buffer_waddr, buffer_wen, clk, next_char, char_address_high, buffer_ren);
   wire [11:0] char_address = { char_address_high, rowc };
   char_rom mychar_rom(char_address, clk, rom_char_row);


   // horizontal & vertical counters
   always @(posedge clk or posedge clr)
     begin
	// reset condition
	if (clr == 1)
	  begin
	     row <= 0;
	     col <= 0;
	     rowc <= 0;
	     colc <= 0;
             char <= 0;
             hsync_flag <= 0;
             char_row <= 0;
 	  end
	else
          begin
             row <= next_row;
             col <= next_col;
             rowc <= next_rowc;
             colc <= next_colc;
             char <= next_char;
             hsync_flag <= next_hsync_flag;
             char_row <= next_char_row;
          end // else: !if(clr == 1)
     end // always @ (posedge clk or posedge clr)

   always @(*)
     begin
        if (vblank)
          begin
	     next_row = 0;
	     next_rowc = 0;
	     next_col = 0;
	     next_colc = 0;
	     next_char = 0;
             next_hsync_flag = 0;
             next_char_row = rom_char_row;
          end
        else if (hblank)
          begin
             // some nice defaults
             next_row = row;
             next_rowc = rowc;
             next_col = 0;
             next_colc = 0;
             next_char = char;
             next_hsync_flag = 0;
             next_char_row = rom_char_row;

             // only do this once per line
             if (hsync_flag == 1)
               begin
		  if (rowc == 15)
		    begin
                       // we are moving to the next row, so char
                       // is already set at the correct value
		       next_row = row + 1;
		       next_rowc = 0;
                    end
		  else
		    begin
                       // we are still on the same row, so
                       // go back to the first char in this line
                       next_char = char - 64;
		       next_rowc = rowc + 1;
		    end // else: !if(rowc == 15)
               end // if (hsync_flag == 1)
          end // if (hblank)
        else
          begin
             // some nice defaults
             next_row = row;
             next_rowc = rowc;
             next_col = col;
             next_colc = colc+1;
             next_char = char;
             next_hsync_flag = 1;
             next_char_row = char_row;

             if (colc == 0)
               next_char = char+1; // we need this as soon as possible
             else if (colc == 7) // we need to move to the next char
               begin
	          next_col = col+1;
                  next_colc = 0;
                  next_char_row = rom_char_row;
               end
	  end // else: !if(hblank)
     end // always @ (posedge clk or posedge clr)

   always @(posedge clk or posedge clr)
     begin
        if (clr)
          begin
             pixel_out <= 0;
          end
        else
          begin
             // XXX I'm not exactly sure why, but without this if, wide chars in the first column
             // (like w) get an extra pixel on the previous column
             if (hblank || vblank)
               pixel_out <= 0;
             else
             // I think the pixel appears a clk late, but it shouldn't be a problem
             // select pixel according to column
               pixel_out <= next_char_row[7-colc];
          end
     end
endmodule