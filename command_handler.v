// TODO define constants for the control chars
module command_handler(
                       input  clk,
                       input  clr,
                       input  px_clk,
                       input  [7:0] data,
                       input  valid,
                       output ready,
                       output [7:0] new_char,
                       output [9:0] new_char_address,
                       output new_char_wen,
                       output [5:0] new_cursor_x,
                       output [3:0] new_cursor_y,
                       output new_cursor_wen,
                       output [3:0] new_first_row,
                       output new_first_row_wen
                       );

   // XXX maybe ready should be registered? reg ready_q;
   reg [7:0] new_char_q;
   reg [9:0] new_char_address_q;
   reg new_char_wen_q;
   reg [5:0] new_cursor_x_q;
   reg [3:0] new_cursor_y_q;
   reg new_cursor_wen_q;
   reg [3:0] new_first_row_q;
   reg new_first_row_wen_q;

   reg [3:0] new_row;
   reg [9:0] last_char_to_erase;

   // state: one hot encoding
   localparam state_char   = 8'b00000001;
   localparam state_esc    = 8'b00000010;
   localparam state_row    = 8'b00000100;
   localparam state_col    = 8'b00001000;
   localparam state_erase  = 8'b00010000;

   reg [7:0] state;

   // the pixel clock & char memory run at half speed, so we can only
   // accept 1 byte every two clocks
   // also if we are erasing part of the screen we can't receive new commands
   assign ready = ~px_clk && (state != state_erase);
   assign new_char = new_char_q;
   assign new_char_address = new_char_address_q;
   assign new_char_wen = new_char_wen_q;
   assign new_cursor_x = new_cursor_x_q;
   assign new_cursor_y = new_cursor_y_q;
   assign new_cursor_wen = new_cursor_wen_q;
   assign new_first_row = new_first_row_q;
   assign new_first_row_wen = new_first_row_wen_q;

   always @(posedge clk or posedge clr) begin
      if (clr) begin
         new_char_q <= 0;
         new_char_address_q <= 0;
         new_char_wen_q <= 0;

         new_cursor_x_q <= 0;
         new_cursor_y_q <= 0;
         new_cursor_wen_q <= 0;

         new_first_row_q <= 0;
         new_first_row_wen_q <= 0;

         state <= state_char;
         new_row <= 0;
         last_char_to_erase <= 0;
      end
      else begin
         if (px_clk) begin
            // when px_clk is up it means the char mem & cursor already had time
            // to write, so we should deassert the write signals
            if (new_char_wen_q) new_char_wen_q <= 0;
            if (new_cursor_wen_q) new_cursor_wen_q <= 0;
            if (new_first_row_wen_q) new_first_row_wen_q <= 0;
         end
         else begin
            // only write to the char mem & cursor
            // just before the px_clock
            if (state == state_erase) begin
               // this state is here because valid isn't true
               // and also we don't need a new char
               if (new_char_address_q == last_char_to_erase) begin
                  // all chars erased
                  state <= state_char;
               end
               else begin
                  // keep erasing
                  new_char_address_q = new_char_address_q + 1;
                  new_char_wen_q <= 1;
               end
            end
            else if (ready && valid) begin
               case (state)
                 state_char: begin
                    // new char arrived
                    if (data >= 8'h20 && data <= 8'h7e) begin
                       // printable char, easy
                       new_char_q <= data;
                       // XXX we can do this because 64 is a power of 2
                       new_char_address_q <= {(new_cursor_y_q+new_first_row_q), new_cursor_x_q};
                       new_char_wen_q <= 1;
                       // no auto linefeed
                       if (new_cursor_x_q != 63) begin
                          new_cursor_x_q <= new_cursor_x_q + 1;
                          new_cursor_wen_q <= 1;
                       end
                    end
                    else begin
                       case (data)
                         // backspace
                         8'h08: begin
                            if (new_cursor_x_q != 0) begin
                               new_cursor_x_q <= new_cursor_x_q - 1;
                               new_cursor_wen_q <= 1;
                            end
                         end
                         // tab
                         8'h09: begin
                            // go until the last tab stop by 8 spaces, then 1 by 1
                            if (new_cursor_x_q < 55) begin
                               new_cursor_x_q <= (new_cursor_x_q + 8) & 6'h38;
                               new_cursor_wen_q <= 1;
                            end
                            else if (new_cursor_x_q != 63) begin
                               new_cursor_x_q <= new_cursor_x_q + 1;
                               new_cursor_wen_q <= 1;
                            end
                         end // case: 8'h09
                         // linefeed
                         8'h0a: begin
                            // XXX this should scroll if on the last line
                            if (new_cursor_y_q == 15) begin
                               new_first_row_q <= new_first_row_q + 1;
                               new_first_row_wen_q <= 1;
                               // erase last line
                               new_char_q <= " ";
                               // XXX we can do this because 64 is a power of 2
                               new_char_address_q <= {new_first_row_q,
                                                      new_cursor_x_q};
                               new_char_wen_q <= 1;
                               // XXX we can do this because 64 is a power of 2
                               last_char_to_erase <= {new_first_row_q, 6'h3f};
                               state <= state_erase;
                            end
                            else begin
                               new_cursor_y_q <= new_cursor_y_q + 1;
                               new_cursor_wen_q <= 1;
                            end
                         end
                         // carriage return
                         8'h0d: begin
                            if (new_cursor_x != 0) begin
                               new_cursor_x_q <= 0;
                               new_cursor_wen_q <= 1;
                            end
                         end
                         // escape
                         8'h1b: begin
                            state <= state_esc;
                         end
                       endcase // case (data)
                    end // else: !if(data >= 8'h20 && data <= 8'h7e)
                 end // case: state_char
                 state_esc: begin
                    case (data)
                      // Basic cursor movement
                      // Esc-only, so no BS, LF & SPACE (covered before)
                      "A": begin
                         if (new_cursor_y_q != 0) begin
                            new_cursor_y_q <= new_cursor_y_q - 1;
                            new_cursor_wen_q <= 1;
                         end
                         state <= state_char;
                      end
                      "B": begin
                         if (new_cursor_y_q != 15) begin
                            new_cursor_y_q <= new_cursor_y_q + 1;
                            new_cursor_wen_q <= 1;
                         end
                         state <= state_char;
                      end
                      "C": begin
                         if (new_cursor_x_q != 63) begin
                            new_cursor_x_q <= new_cursor_x_q + 1;
                            new_cursor_wen_q <= 1;
                         end

                         state <= state_char;
                      end
                      "D": begin
                         if (new_cursor_x_q != 0) begin
                            new_cursor_x_q <= new_cursor_x_q - 1;
                            new_cursor_wen_q <= 1;
                         end
                         state <= state_char;
                      end
                      // Advanced cursor movement
                      // Esc-only, so no CR & TAB (covered before)
                      "H": begin
                         new_cursor_x_q <= 0;
                         new_cursor_y_q <= 0;
                         new_cursor_wen_q <= 1;
                         state <= state_char;
                      end
                      "Y": begin
                         // "Y" received, expecting row & col
                         state <= state_row;
                      end
                      // Screen erasure
                      "K": begin
                         // erase to end of line
                         new_char_q <= " ";
                         // XXX we can do this because 64 is a power of 2
                         new_char_address_q <= {(new_cursor_y_q+new_first_row_q),
                                                new_cursor_x_q};
                         new_char_wen_q <= 1;
                         // XXX we can do this because 64 is a power of 2
                         last_char_to_erase <= {(new_cursor_y_q+new_first_row_q), 6'h3f};
                         state <= state_erase;
                      end
                      "J": begin
                         // erase to end of screen
                         new_char_q <= " ";
                         // XXX we can do this because 64 is a power of 2
                         new_char_address_q <= {(new_cursor_y_q+new_first_row_q),
                                                new_cursor_x_q};
                         new_char_wen_q <= 1;
                         last_char_to_erase <= { (new_first_row_q-1),
                                                 6'h3f };
                         state <= state_erase;
                      end
                      // escape
                      8'h1b: begin
                         // on VT52 two escapes don't cancel each other
                         // do nothing
                      end
                      default: begin
                         // unrecognized escape sequence, back to normal
                         state <= state_char;
                      end
                    endcase // case (data)
                 end // case: state_esc
                 state_row: begin
                    // row received, now we need col
                    new_row <= (data >= 8'h20 && data < (8'h20 + 16))? data - 8'h20 : new_cursor_y;
                    state <= state_col;
                 end
                 state_col: begin
                    // row & col received, move cursor and go back to idle
                    // XXX I'm not sure what happens if data < 8'h20, this is a guess
                    new_cursor_x_q <= (data >= 8'h20 && data < (8'h20 + 64))?
                                      data - 8'h20 : 63;
                    new_cursor_y_q <= new_row;
                    new_cursor_wen_q <= 1;
                    state <= state_char;
                 end // if (state == state_col)
                 // we can't have state_erase here, because in that
                 // case valid wouldn't be true and we don't need a new char
                 default: begin
                    // shouldn't happen
                    state <= state_char;
                 end
               endcase // case (state)
            end // if (ready && valid)
         end // else: !if(px_clk)
      end // else: !if(clr)
   end // always @ (posedge clk or posedge clr)
endmodule
