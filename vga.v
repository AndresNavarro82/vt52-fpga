// 1280x1024@60Hz
/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:  108.000 MHz
 * Achieved output frequency:   108.000 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b1000111),	// DIVF = 71
		.DIVQ(3'b011),		// DIVQ =  3
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clock_in),
		.PLLOUTCORE(clock_out)
		);

endmodule

module led_divider(
                   input wire  clk_in,
                   output wire [4:0] led_out
                   );

   reg [9:0]                   counter = 10'b0;   
   always @(posedge clk_in)
     begin
        counter <= counter + 1;
     end
   assign led_out = counter[9:5];   
endmodule

module top (
	    input wire  pclk,
	    input wire  clr, //asynchronous reset
	    output wire hsync,
	    output wire vsync,
	    output wire video,
	    output wire LED1,
	    output wire LED2,
	    output wire LED3,
	    output wire LED4,
	    output wire LED5,
            );

    // VESA Signal 1280 x 1024 @ 60 Hz timing (native res for a LG LX40 17" lcd)
    // from http://tinyvga.com/vga-timing/1280x1024@75Hz
    parameter hpixels = 1688; // horizontal pixels per line
    parameter hbp = 248; 	// horizontal back porch
    parameter hvisible = 1280; // horizontal visible area pixels
    parameter hfp = 48; 	// horizontal front porch
    parameter hpulse = 112;	// hsync pulse length

    parameter vlines = 1066; // vertical lines per frame
// XXX removed some lines so that a centered area of 800 lines 
// (25 lines of 32 pixels) 
    parameter vbp = 38+112; 	// vertical back porch
    parameter vvisible = 1024-224; // vertical visible area lines
    parameter vfp = 1+112; 	// vertical front porch
// 
//    parameter vbp = 38; 	// vertical back porch
//    parameter vvisible = 1024; // vertical visible area lines
//    parameter vfp = 1; 	// vertical front porch
    parameter vpulse = 3; 	// vsync pulse length

   parameter video_on = 1'b1;
   parameter hsync_on = 1'b1;
   parameter vsync_on = 1'b1;

   
   localparam hsync_off = ~hsync_on;
   localparam video_off = ~video_on;
   localparam vsync_off = ~vsync_on;

   // registers for storing the horizontal & vertical counters
   reg [10:0]           hc = 0;
   reg [10:0]           vc = 0;

   wire                 pll_clk, locked;
   wire                 clk;
   wire                 video_out;
   wire                 vblank, hblank;
   
   
   pll mypll(pclk,pll_clk,locked);
   assign clk = pll_clk;
   
   

// XXX chars

reg [5:0] row = 0;
reg [6:0] col = 0;

reg [3:0] colc = 0;
reg [4:0] rowc = 0;

reg [10:0] char = 0;

reg[7:0] char_mem[4095:0];
reg[7:0] ascii_mem[1999:0];
reg[7:0] char_row;
reg[7:0] new_char_row;
reg[11:0] char_address;

initial 
begin
   $readmemh("pantalla/pantalla.hex", ascii_mem) ;
   $readmemh("font/terminus_816_latin1.hex", char_mem) ;
end

// XXX /chars
   
   // syncs, blanks & leds
   assign hsync = (hc >= hbp + hvisible + hfp)? hsync_on : hsync_off;
   assign vsync = (vc >= vbp + vvisible + vfp)? vsync_on : vsync_off;

   // blank wires to simplify some expressions later
   assign hblank = (hc < hbp || hc >= hbp + hvisible);
   assign vblank = (vc < vbp || vc >= vbp + vvisible);

   assign video_out = char_row[7-(colc>>1)];
   assign video = (hblank || vblank)? video_off : video_out;
                 
   led_divider myled_divider(vblank, {LED1, LED2, LED3, LED4, LED5});   

   always @(posedge clk or posedge clr)
     begin
	// reset condition
	if (clr == 1)
	  begin
	     hc <= 0;
	     vc <= 0;
             // char
		row <= 0;
		col <= 0;
		colc <= 0;
		rowc <= 0;
             // /char
 	  end
	else
	  begin
             if (hc == hpixels)
               // end of line reached
	       begin
		  hc <= 0;
		  if (vc == vlines)
                    // end of screen reached, go back
                    begin
		       vc <= 0;
		       char <= 0;
                    end
		  else
		    begin
		       vc <= vc + 1;
                       
                       // char management
                       // no need to set char row or address here, already set during
                       // blank periods
                       if (!vblank) 
			 begin
			    if (rowc < 31)
			      begin
                                 // we are still on the same row, so
                                 // go back to the first char in this line
				 char <= char - 80;
				 rowc <= rowc + 1;
                              end
			    else
			      begin
                                 // we are moving to the next row, so char
                                 // is already set at the correct value
				 row <= row + 1;
				 rowc <= 0;
			      end // else: !if(rowc < 31)
			 end // if (!vblank)
		    end // else: !if(vc == vlines)
	       end // if (hc == hpixels)
             else
	       begin
		  hc <= hc + 1;
                  // char
		  if (hblank || vblank)
                    // char_row will need several passes of this code
                    // in order to get the correct value, but we
                    // have plenty of time.
		    begin
		       col <= 0;
		       colc <= 0;
 		       char_address <= ascii_mem[char]<<4;
		       new_char_row <= char_mem[char_address+(rowc>>1)];		
                       char_row <= new_char_row;
		    end
		  else
		    // update char col if in active area
		    begin
		       if (colc < 15)
                         begin
			    colc <= colc+1;
                            // we need this ready for when colc == 15
                            char_address <= (ascii_mem[char+1]<<4);
			    new_char_row <= char_mem[char_address+(rowc>>1)];		
                         end
                       else 
			 begin
			    colc <= 0;
			    col <= col+1;
			    char <= char + 1;
                            char_row <= new_char_row;
			 end
		    end // else: !if(hblank || vblank)
	       end // else: !if(hc == hpixels)
          end // else: !if(clr == 1)
     end // always @ (posedge clk or posedge clr)
endmodule
