/**
 * Char Buffer RAM (2000x8)
 * (25 lines of 80 characters)
 */
module char_buffer
  #(parameter BUF_SIZE = 2000,
    parameter ADDR_BITS = 11)
   (din, waddr, write_en, clk, raddr, dout, read_en);
   input wire [7:0] din;
   input wire [ADDR_BITS-1:0] waddr;
   input wire  write_en, clk;
   input wire [ADDR_BITS-1:0] raddr;
   output reg [7:0] dout;
   input wire       read_en;

   reg [7:0]    mem [BUF_SIZE-1:0];

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
