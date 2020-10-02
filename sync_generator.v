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
                       output wire       px_clk,
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
   parameter vpulse = 3; 	// vsync pulse lengt

   parameter video_on = 1'b1;
   parameter hsync_on = 1'b1;
   parameter vsync_on = 1'b1;

   localparam hsync_off = ~hsync_on;
   localparam video_off = ~video_on;
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
