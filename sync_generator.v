`include "pll.v"

/**
 * VGA sync generator
 */
module sync_generator (
		       input             clk12, // 12MHz clock
                       input             clr, // async reset
                       // XXX maybe these should be regs??
		       output reg       hsync,
		       output reg       vsync,
		       output reg       hblank,
		       output reg       vblank,
                       output reg [10:0] hc,
                       output reg [10:0] vc,
                       output wire       px_clk
		       );

   // VGA Signal 640x480 @ 60 Hz timing
   // from http://tinyvga.com/vga-timing/640x480@60Hz
   parameter hpixels = 800; // horizontal pixels per line
   // XXX removed some columns to leave just 64 columns of 8 pixels (512)
//   parameter hbp = 48; 	// horizontal back porch
//   parameter hvisible = 640; // horizontal visible area pixels
//   parameter hfp = 16; 	// horizontal front porch
   parameter hbp = 48 + 64; 	// horizontal back porch
   parameter hvisible = 640 - 128; // horizontal visible area pixels
   parameter hfp = 16 + 64; 	// horizontal front porch
   parameter hpulse = 96;	// hsync pulse length

   parameter vlines = 525; // vertical lines per frame
   // XXX removed some lines to leave just 16 lines of 16 pixels (256)
   //    parameter vbp = 33; 	// vertical back porch
   //    parameter vvisible = 480; // vertical visible area lines
   //    parameter vfp = 10; 	// vertical front porch
   parameter vbp = 33+112; 	// vertical back porch
   parameter vvisible = 480 - 224; // vertical visible area lines
   parameter vfp = 10+112; 	// vertical front porch
   parameter vpulse = 2; 	// vsync pulse length

   parameter hsync_on = 1'b0;
   parameter vsync_on = 1'b0;
   localparam hsync_off = ~hsync_on;
   localparam vsync_off = ~vsync_on;

   wire locked;
   pll mypll(clk12, px_clk, locked);

   reg  [10:0] next_hc, next_vc;
   reg  next_hsync, next_vsync;
   reg  next_hblank, next_vblank;

   // horizontal & vertical counters
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
             hc = next_hc;
             vc = next_vc;
          end
     end


   always @(hc or vc)
     begin
        // horizontal & vertical counters
        if (hc == hpixels) // end of line reached
	  begin
	     next_hc = 0;
	     if (vc == vlines) // end of screen reached, go back
	       next_vc = 0;
	     else
	       next_vc = vc + 1;
	  end
        else
          begin
	     next_hc = hc + 1;
             next_vc = vc;
          end

        // syncs & blanks
        next_hsync = (next_hc >= hbp + hvisible + hfp)? hsync_on : hsync_off;
        next_vsync = (next_vc >= vbp + vvisible + vfp)? vsync_on : vsync_off;
        next_hblank = (next_hc < hbp || next_hc >= hbp + hvisible);
        next_vblank = (next_vc < vbp || next_vc >= vbp + vvisible);
     end // always @ (*)

   // syncs & blanks
   always @(posedge px_clk or posedge clr)
     begin
        if (clr)
          begin
             hsync <= hsync_off;
             vsync <= vsync_off;
             hblank <= 1'b1;
             vblank <= 1'b1;
          end
        else
          begin
             hsync <= next_hsync;
             vsync <= next_vsync;
             hblank <= next_hblank;
             vblank <= next_vblank;
          end
     end
 endmodule
