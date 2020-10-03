`include "pll.v"

/**
 * VGA sync generator
 */
module sync_generator (
		       input             clk12, // 12MHz clock
                       input             clr, // async reset
                       // XXX maybe these should be regs??
		       output wire       hsync,
		       output wire       vsync,
		       output wire       hblank,
		       output wire       vblank,
                       output reg [10:0] hc,
                       output reg [10:0] vc,
                       output wire       px_clk
		       );

   // VGA Signal 640x480 @ 60 Hz timing
   // from http://tinyvga.com/vga-timing/640x480@60Hz
   parameter hpixels = 800; // horizontal pixels per line
   // XXX removed some columns to leave just 64 lines of 8 pixels (512)
   parameter hbp = 48 + 64; 	// horizontal back porch
   parameter hvisible = 640 - 128; // horizontal visible area pixels
   parameter hfp = 16 + 64; 	// horizontal front porch
//   parameter hbp = 48; 	// horizontal back porch
//   parameter hvisible = 640; // horizontal visible area pixels
//   parameter hfp = 16; 	// horizontal front porch
   parameter hpulse = 96;	// hsync pulse length

   parameter vlines = 525; // vertical lines per frame
   // XXX removed some lines to leave just 16 lines of 16 pixels (256)
   parameter vbp = 33+112; 	// vertical back porch
   parameter vvisible = 480 - 224; // vertical visible area lines
   parameter vfp = 10+112; 	// vertical front porch
   // (25 lines of 32 pixels)
   //
   //    parameter vbp = 33; 	// vertical back porch
   //    parameter vvisible = 480; // vertical visible area lines
   //    parameter vfp = 10; 	// vertical front porch
   parameter vpulse = 2; 	// vsync pulse length

   parameter hsync_on = 1'b0;
   parameter vsync_on = 1'b0;

   localparam hsync_off = ~hsync_on;
   localparam vsync_off = ~vsync_on;

   wire locked;
   pll mypll(clk12, px_clk, locked);

   // TODO refactor (maybe set next_hc, next_vc in always @*, and do
   // sync & blanks there too)

   // syncs & blanks
   assign hsync = (hc >= hbp + hvisible + hfp)? hsync_on : hsync_off;
   assign vsync = (vc >= vbp + vvisible + vfp)? vsync_on : vsync_off;

   // blank wires to simplify some expressions later
   assign hblank = (hc < hbp || hc >= hbp + hvisible);
   assign vblank = (vc < vbp || vc >= vbp + vvisible);

   always @(posedge px_clk or posedge clr)
     begin
	// reset condition
	if (clr == 1)
	  begin
	     hc <= 0;
	     vc <= 0;
 	  end
	else
	  begin
             if (hc == hpixels) // end of line reached
	       begin
		  hc <= 0;
		  if (vc == vlines) // end of screen reached, go back
		       vc <= 0;
		  else
		       vc <= vc + 1;
	       end
             else
	       hc <= hc + 1;
          end // else: !if(clr == 1)
     end // always @ (posedge px_clk or posedge clr)
endmodule
