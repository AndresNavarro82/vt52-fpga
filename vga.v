`include "pll.v"
`include "led_counter.v"
`include "char_rom.v"
`include "char_buffer.v"
`include "sync_generator.v"

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
	    output wire LED5,
            );

   // for storing the horizontal & vertical counters
   wire [10:0]           hc;
   wire [10:0]           vc;

   wire                 px_clk;
   wire                 video_out;
   wire                 vblank, hblank;
   
   reg [5:0]            row = 0;
   reg [6:0]            col = 0;

   reg [3:0]            colc = 0;
   reg [4:0]            rowc = 0;

   reg [10:0]           char = 0;

   reg [7:0]            char_row;
   wire [11:0]          char_address;
   wire [7:0]           char_address_high;

   wire [7:0] next_char_row;
   reg [10:0] next_char;
   // write function not used for now
   wire [7:0] buffer_din = 8'b0;
   wire       buffer_wen = 1'b0;

   sync_generator mysync_generator(pclk, clr, hsync, vsync, hblank, vblank, hc, vc, px_clk);
   led_counter myled_counter(vblank, {LED1, LED2, LED3, LED4, LED5});
   char_buffer mychar_buffer(buffer_din, next_char, buffer_wen, px_clk, char_address_high);
   char_rom mychar_rom(char_address, px_clk, next_char_row);

   // The address of the char row is formed with the char and the row offset
   assign char_address = { char_address_high, rowc[4:1] };
   // only emit video on non-blanking, select pixel according to column
   assign video_out = char_row[7-(colc>>1)];
   assign video = (hblank || vblank)? video_off : video_out;

   // TODO refactor and move to new file
   always @(posedge px_clk or posedge clr)
     begin
	// reset condition
	if (clr == 1)
	  begin
	     row <= 0;
	     col <= 0;
	     colc <= 0;
	     rowc <= 0;
 	  end
	else
	  begin
             if (vblank)
               begin
	          row <= 0;
	          col <= 0;
	          colc <= 0;
	          rowc <= 0;
		  char <= 0;
               end
             else if (hblank)
               begin
                  if (col == 0)
                    begin
                       // we need a couple of passes of this
                       next_char = char;
                       char_row <= next_char_row;
                    end
                  else
                    begin
                       // only do this once per line
                       col <= 0;
                       colc <= 0;
		       if (rowc == 31)
			 begin
                            // we are moving to the next row, so char
                            // is already set at the correct value
                            // next_char <= char;
                            next_char <= char;
			    row <= row + 1;
			    rowc <= 0;
                         end
		       else
			 begin
                            // we are still on the same row, so
                            // go back to the first char in this line
			    next_char <= char - 80;
                            char = char - 80;
                            row <= row;
			    rowc <= rowc + 1;
			 end // else: !if(rowc == 31)
                    end // if (col != 0)
               end // if (hblank)
             else
	       begin
		  // update char col if in active area
		  if (colc < 15)
                    begin
		       colc <= colc+1;
                       // we need this ready for when colc == 15
                       next_char <= char+1;
                    end
                  else
		    begin
		       colc <= 0;
		       col <= col+1;
		       char <= char + 1;
                       char_row <= next_char_row;
		    end // else: !if(colc < 15)
               end // else: !if(hblank)
          end // else: !if(clr == 1)
     end // always @ (posedge px_clk or posedge clr)
endmodule
