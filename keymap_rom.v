/**
 * Keymap ROM (1KB, maps keycodes to ASCII chars)
 * This could be a RAM to allow keymap modifications, but not for now
 * There's 4 planes for each keycode (controlled by the highest two bits)
 * 00: no shift or caps lock
 * 01: just shift
 * 10: just caps lock
 * 11: caps lock & shift
 */
module keymap_rom
  (input clk,
   input [9:0] addr,
   output [7:0] dout
   );

   reg [7:0]    dout;
   reg [7:0]    mem [1023:0];

   integer i;

   initial begin
      // the hex file is sparse, prefill with zeros
      // XXX yosys doesn't like this, it overrides the readmemh
      // so for now just assume that all other positions have zeros...
      // for (i = 0; i < 1023; i = i + 1) mem[i] = "b";
      $readmemh("mem/keymap.hex", mem) ;
   end

   always @(posedge clk) begin
      dout = mem[addr];
   end
endmodule
