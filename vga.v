`include "led_counter.v"
`include "char_rom.v"
`include "char_buffer.v"
`include "sync_generator.v"
`include "cursor_blinker.v"

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
   
   reg [3:0]            row = 0;
   reg [5:0]            col = 0;

   reg [2:0]            colc = 0;
   reg [3:0]            rowc = 0;

   reg [9:0]           char = 0;

   // cursor
   reg [3:0]            cursor_y = 0;
   reg [5:0]            cursor_x = 0;
   wire                 cursor_blink_on;
   // /cursor
   reg [7:0]            char_row;
   wire [11:0]          char_address;
   wire [7:0]           char_address_high;

   wire [7:0] next_char_row;
   reg [9:0] next_char;
   // write function not used for now
   wire [7:0] buffer_din = 8'b0;
   wire       buffer_wen = 1'b0;

   reg        hsync_flag = 0;

   sync_generator mysync_generator(pclk, clr, hsync, vsync, hblank, vblank, hc, vc, px_clk);
   led_counter myled_counter(vblank, {LED1, LED2, LED3, LED4, LED5});
   char_buffer mychar_buffer(buffer_din, next_char, buffer_wen, px_clk, char_address_high);
   char_rom mychar_rom(char_address, px_clk, next_char_row);
   cursor_blinker mycursor_blinker(vblank, clr, cursor_blink_on);

   // The address of the char row is formed with the char and the row offset
   assign char_address = { char_address_high, rowc };

   parameter video_on = 1'b1;
   localparam video_off = ~video_on;

   wire                 is_under_cursor;
   assign is_under_cursor = (cursor_x == col) & (cursor_y == row);
   wire                 cursor_xor;
   // invert video when we are under the cursor & it's blinking
   assign cursor_xor = is_under_cursor & cursor_blink_on;

   // only emit video on non-blanking, select pixel according to column
   assign video_out = char_row[7-colc] ^ cursor_xor;
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
             // cursor
             cursor_y <= 0;
             cursor_x <= 0;
             // /cursor
             hsync_flag = 0;
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
                  if (hsync_flag == 0)
                    begin
                       // we need a couple of passes of this
                       char_row <= next_char_row;
                    end
                  else
                    begin
                       // only do this once per line
                       hsync_flag <= 0;
                       col <= 0;
                       colc <= 0;
		       if (rowc == 15)
			 begin
                            // we are moving to the next row, so char
                            // is already set at the correct value
			    row <= row + 1;
			    rowc <= 0;
                         end
		       else
			 begin
                            // we are still on the same row, so
                            // go back to the first char in this line
                            char <= char - 64;
                            next_char <= char - 64;
                            row <= row;
			    rowc <= rowc + 1;
			 end // else: !if(rowc == 15)
                    end // if (col != 0)
               end // if (hblank)
             else
	       begin
                  hsync_flag <= 1;
		  // update char col if in active area
		  if (colc < 7)
                    begin
		       colc <= colc+1;
                       if (colc == 0) // we need this as soon as possible
                         next_char <= char+1;
                    end
                  else
		    begin
		       colc <= 0;
		       col <= col+1;
                       char <= char + 1;
                       char_row <= next_char_row;
		    end // else: !if(colc < 7)
               end // else: !if(hblank)
          end // else: !if(clr == 1)
     end // always @ (posedge px_clk or posedge clr)
endmodule
