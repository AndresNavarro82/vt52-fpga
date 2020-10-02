/**
 * Char Buffer RAM (2kx8)
 * Only 2000 positions used (25 lines of 80 characters)
 */
module char_buffer (din, addr, write_en, clk, dout);
   parameter addr_width = 11;
   parameter data_width = 8;
   input [addr_width-1:0] addr;
   input [data_width-1:0] din;
   input 		  write_en, clk;
   output [data_width-1:0] dout;
   reg [data_width-1:0]    dout; // Register for output.
   reg [data_width-1:0]    mem [(1<<addr_width)-1:0];

   initial
     begin
	$readmemh("pantalla/pantalla.hex", mem) ;
     end

   always @(posedge clk)
     begin
	if (write_en)
	  mem[(addr)] <= din;
	dout = mem[addr]; // Output register controlled by clock.
     end
endmodule
