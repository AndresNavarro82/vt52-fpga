/**
 * Cursor (position and blinking)
 */
module cursor
  #(parameter ROW_BITS = 5,
    parameter COL_BITS = 7)
   (input clk,
    input reset,
    input vblank,
    output wire [COL_BITS-1:0] cursor_x,
    output wire [ROW_BITS-1:0] cursor_y,
    output wire cursor_blink_on,
    input [COL_BITS-1:0] new_cursor_x,
    input [ROW_BITS-1:0] new_cursor_y,
    input new_cursor_wen
    );

   cursor_blinker mycursor_blinker(clk, reset, vblank, new_cursor_wen, cursor_blink_on);
   simple_register #(.SIZE(COL_BITS)) mycursor_x (clk, reset, new_cursor_x, new_cursor_wen, cursor_x);
   simple_register #(.SIZE(ROW_BITS)) mycursor_y (clk, reset, new_cursor_y, new_cursor_wen, cursor_y);
endmodule
