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

   reg ready_q;
   reg [7:0] new_char_q;
   reg new_char_wen_q;
   reg [5:0] new_cursor_x_q;
   reg [3:0] new_cursor_y_q;
   reg new_cursor_wen_q;

   // the pixel clock & char memory runs at half speed, so we can only
   // accept 1 byte every two clocks
   assign ready = ~px_clk;
   assign new_char = new_char_q;
   assign new_char_wen = new_char_wen_q;
   assign new_cursor_x = new_cursor_x_q;
   assign new_cursor_y = new_cursor_y_q;
   assign new_cursor_wen = new_cursor_wen_q;

   always @(posedge clk or posedge clr) begin
      if (clr) begin
         new_char_q <= 0;
         new_char_wen_q <= 0;

         new_cursor_x_q <= 0;
         new_cursor_y_q <= 0;
         new_cursor_wen_q <= 0;
      end
      else begin
         if (ready && valid) begin
            // new char arrived
            //case (data)
            new_char_q <= data;
            new_char_wen_q <= 1;
            if (new_cursor_x_q < 63) begin
               new_cursor_x_q <= new_cursor_x_q + 1;
               new_cursor_wen_q <= 1;
            end
         end
         else if (new_char_wen_q || new_cursor_wen_q) begin
            // after one clock deassert the write signals
            new_char_wen_q <= 0;
            new_cursor_wen_q <= 0;
         end
      end
   end
endmodule
