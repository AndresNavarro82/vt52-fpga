/**
 * Char Buffer RAM (1kx8)
 * (16 lines of 64 characters)
 */
module char_buffer (din, addr, write_en, clk, dout);
   input [9:0] addr;
   input [7:0] din;
   input 		  write_en, clk;
   output [7:0] dout;
   reg [7:0]    dout; // Register for output.
   reg [7:0]    mem [1023:0];

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
