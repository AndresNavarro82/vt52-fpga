/**
 * Cursor position (just one dimension, we'll need two of these)
 */
module cursor_position
  #(parameter SIZE = 8)
   (input wire clk,
    input wire reset,
    input wire [SIZE-1:0] ipos,
    input wire            wen,
    output reg [SIZE-1:0] opos
    );

   always @(posedge clk) begin
      if (reset) opos <= 0;
      else if (wen) opos = ipos;
   end
endmodule
