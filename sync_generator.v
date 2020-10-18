/**
 * VGA sync generator
 */
module sync_generator (
		       input clk,
                       input clr,
		       output reg hsync,
		       output reg vsync,
		       output reg hblank,
		       output reg vblank
		       );

   // VGA Signal 640x400 @ 70 Hz timing
   // from http://tinyvga.com/vga-timing/640x400@70Hz
   // Total size, visible size, front and back proches and sync pulse size
   // clk is 48Mhz (because USB...), so twice what we need (around 25Mhz)
   // Every horizontal value is multiplied by two because we have a clock
   // that runs at twice the pixel rate
   localparam hbits = 12;
   localparam hpixels = 2*800;
   localparam hbp = 2*48;
   localparam hvisible = 2*640;
   localparam hfp = 2*16;
   localparam hpulse = 2*96;
   // Added 8 to vbp and vfp to compensate for the missing character row
   // (24 instead of 25, each row is 16 pixels)
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

   // horizontal & vertical counters
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
endmodule
