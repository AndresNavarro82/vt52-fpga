module command_handler(
                       input  clk,
                       input  clr,
                       input  px_clk,
                       input  [7:0] data,
                       input  valid,
                       output ready,
                       output [7:0] new_char,
                       output new_char_wen,
                       output [5:0] new_cursor_x,
                       output [3:0] new_cursor_y,
                       output new_cursor_wen
                       );
   assign ready = 0;
   assign new_char = 0;
   assign new_char_wen = 0;
   assign new_cursor_x = 0;
   assign new_cursor_y = 0;
   assign new_cursor_wen = 0;
endmodule
