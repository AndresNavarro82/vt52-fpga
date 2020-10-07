/**
 * Char Buffer RAM (1kx8)
 * (16 lines of 64 characters)
 */
module char_buffer (din, waddr, write_en, clk, raddr, dout, read_en);
   input wire [7:0] din;
   input wire [9:0] waddr;
   input wire  write_en, clk;
   input wire [9:0] raddr;
   output reg [7:0] dout;
   input wire       read_en;

   reg [7:0]    mem [1023:0];

   initial
     begin
//	$readmemh("pantalla/pantalla.hex", mem) ;
	$readmemh("pantalla/empty.hex", mem) ;
     end

   always @(posedge clk)
     begin
	if (write_en)
	  mem[waddr] <= din;
        if (read_en)
	  dout <= mem[raddr]; // Output register controlled by clock.
     end
endmodule
