// TODO define constants for the control chars
// TODO define constants for the control codes
module keyboard(
                input  clk,
                input  clr,
                input  ps2_data,
                input  ps2_clk,
                output [7:0] data,
                output valid,
                input ready
                );

   reg [7:0] data_q;
   reg       valid_q;

   assign data = data_q;
   assign valid = valid_q;

   reg [1:0] ps2_old_clks;
   reg [10:0] ps2_raw_data;
   reg [3:0]  ps2_count;
   reg [7:0]  ps2_byte;
   // we are processing a break_code (key up)
   reg        ps2_break_keycode;
   // we are processing a long keycode (two bytes)
   reg        ps2_long_keycode;
   // shift key status
   reg        lshift_pressed;
   reg        rshift_pressed;
   // TODO control keys

   // we don't need to do this on the pixel clock, we could use
   // something way slower, but it works
   always @ (posedge clk or posedge clr) begin
      if (clr) begin
         data_q <= 0;
         valid_q <= 0;

         // the clk is usually high and pulled down to start
         ps2_old_clks <= 2'b00;
         ps2_raw_data <= 0;
         ps2_count <= 0;
         ps2_byte <= 0;

         ps2_break_keycode <= 0;
         ps2_long_keycode <= 0;

         lshift_pressed <= 0;
         rshift_pressed <= 0;
      end
      else begin
         if (valid && ready) begin
            valid_q <= 0;
            ps2_break_keycode <= 0;
            ps2_long_keycode <= 0;
            ps2_byte <= 0;
         end
         ps2_old_clks <= {ps2_old_clks[0], ps2_clk};

         if(ps2_clk && ps2_old_clks == 2'b01) begin
            ps2_count <= ps2_count + 1;
            if(ps2_count == 10) begin
               // 11 bits means we are done (XXX/TODO check parity and stop bits)
               ps2_count <= 0;
               ps2_byte <= ps2_raw_data[10:3];
               // handle the breaks & long keycodes
               if (ps2_raw_data[10:3] == 8'he0) begin
                  ps2_long_keycode <= 1;
                  ps2_break_keycode <= 0;
               end
               else if (ps2_raw_data[10:3] == 8'hf0) begin
                  ps2_break_keycode <= 1;
               end
               else if (ps2_byte != 8'he0 && ps2_byte != 8'hf0) begin
                  ps2_break_keycode <= 0;
                  ps2_long_keycode <= 0;
               end
            end
            // the data comes lsb first
            ps2_raw_data <= {ps2_data, ps2_raw_data[10:1]};
         end // if (ps2_clk_pos == 1)
         if (!valid) begin
            // only process new char if none are queued
            if (ps2_break_keycode) begin
               // keyup
               if (!ps2_long_keycode) begin
                  // keyup: short keycode
                  if (ps2_byte == 8'h12)  begin
                       lshift_pressed <= 0;
                       // XXX this will not clear the char, maybe use a flag reg for this,
                       // like char processed, instead of relying on new_char_wen &
                       // // write_cursor_pos
                    end
                  if (ps2_byte == 8'h59) begin
                       rshift_pressed <= 0;
                       // XXX this will not clear the char, maybe use a flag reg for this,
                       // like char processed, instead of relying on new_char_wen &
                       // // write_cursor_pos
                  end
               end
            end
            else begin
               // keydown
               if(ps2_long_keycode) begin
                  if(ps2_byte == 8'h14) begin // right control
                     // TODO
                  end
               end // if (ps2_long_keycode)
               else begin
                  // TODO control handling
                  if (lshift_pressed || rshift_pressed) begin
                     // keydown: short keycode (shift pressed)
                     valid_q <= 1;
                     case (ps2_byte)
                       8'h0e: data_q <= "~";
                       8'h16: data_q <= "!";
                       8'h1e: data_q <= "@";
                       8'h26: data_q <= "#";
                       8'h25: data_q <= "$";
                       8'h2e: data_q <= "%";
                       8'h36: data_q <= "^";
                       8'h3d: data_q <= "&";
                       8'h3e: data_q <= "*";
                       8'h46: data_q <= "(";
                       8'h45: data_q <= ")";
                       8'h4e: data_q <= "_";
                       8'h55: data_q <= "+";
                       8'h5d: data_q <= "|";

                       8'h15: data_q <= "Q";
                       8'h1d: data_q <= "W";
                       8'h24: data_q <= "E";
                       8'h2d: data_q <= "R";
                       8'h2c: data_q <= "T";
                       8'h35: data_q <= "Y";
                       8'h3c: data_q <= "U";
                       8'h43: data_q <= "I";
                       8'h44: data_q <= "O";
                       8'h4d: data_q <= "P";
                       8'h54: data_q <= "{";
                       8'h5b: data_q <= "}";

                       8'h1c: data_q <= "A";
                       8'h1b: data_q <= "S";
                       8'h23: data_q <= "D";
                       8'h2b: data_q <= "F";
                       8'h34: data_q <= "G";
                       8'h33: data_q <= "H";
                       8'h3b: data_q <= "J";
                       8'h42: data_q <= "K";
                       8'h4b: data_q <= "L";
                       8'h4c: data_q <= ":";
                       8'h52: data_q <= "\"";

                       8'h1a: data_q <= "Z";
                       8'h22: data_q <= "X";
                       8'h21: data_q <= "C";
                       8'h2a: data_q <= "V";
                       8'h32: data_q <= "B";
                       8'h31: data_q <= "N";
                       8'h3a: data_q <= "M";
                       8'h41: data_q <= "<";
                       8'h49: data_q <= ">";
                       8'h4a: data_q <= "?";

                       // escape
                       8'h76: data_q <= "\033";
                       // tab
                       8'h0d: data_q <= "\t";
                       // backspace
                       8'h66: data_q <= "\010";
                       // space
                       8'h29: data_q <= " ";
                       // return
                       8'h5a: data_q <= "\r";
                       // shifts
                       8'h12: begin
                          lshift_pressed <= 1;
                          valid_q <= 0;
                          // XXX this will not clear the char, maybe use a flag reg for this,
                          // like char processed, instead of relying on new_char_wen &
                          // // write_cursor_pos
                       end
                       8'h59: begin
                          rshift_pressed <= 1;
                          valid_q <= 0;
                          // XXX this will not clear the char, maybe use a flag reg for this,
                          // like char processed, instead of relying on new_char_wen &
                          // // write_cursor_pos
                       end
                       // caps lock
                       8'h58: begin
                          // TODO caps lock
                       end
                       default: begin
                          valid_q <= 0;
                       end
                     endcase // case (ps2_byte)
                  end // if (lshift_pressed || rshift_pressed)
                  else begin
                     // keydown: short keycode (no shift pressed)
                     valid_q <= 1;
                     case (ps2_byte)
                       8'h0e: data_q <= "`";
                       8'h16: data_q <= "1";
                       8'h1e: data_q <= "2";
                       8'h26: data_q <= "3";
                       8'h25: data_q <= "4";
                       8'h2e: data_q <= "5";
                       8'h36: data_q <= "6";
                       8'h3d: data_q <= "7";
                       8'h3e: data_q <= "8";
                       8'h46: data_q <= "9";
                       8'h45: data_q <= "0";
                       8'h4e: data_q <= "-";
                       8'h55: data_q <= "=";
                       8'h5d: data_q <= "\\";

                       8'h15: data_q <= "q";
                       8'h1d: data_q <= "w";
                       8'h24: data_q <= "e";
                       8'h2d: data_q <= "r";
                       8'h2c: data_q <= "t";
                       8'h35: data_q <= "y";
                       8'h3c: data_q <= "u";
                       8'h43: data_q <= "i";
                       8'h44: data_q <= "o";
                       8'h4d: data_q <= "p";
                       8'h54: data_q <= "[";
                       8'h5b: data_q <= "]";

                       8'h1c: data_q <= "a";
                       8'h1b: data_q <= "s";
                       8'h23: data_q <= "d";
                       8'h2b: data_q <= "f";
                       8'h34: data_q <= "g";
                       8'h33: data_q <= "h";
                       8'h3b: data_q <= "j";
                       8'h42: data_q <= "k";
                       8'h4b: data_q <= "l";
                       8'h4c: data_q <= ";";
                       8'h52: data_q <= "'";

                       8'h1a: data_q <= "z";
                       8'h22: data_q <= "x";
                       8'h21: data_q <= "c";
                       8'h2a: data_q <= "v";
                       8'h32: data_q <= "b";
                       8'h31: data_q <= "n";
                       8'h3a: data_q <= "m";
                       8'h41: data_q <= ",";
                       8'h49: data_q <= ".";
                       8'h4a: data_q <= "/";
                       // escape
                       8'h76: data_q <= "\033";
                       // tab
                       8'h0d: data_q <= "\t";
                       // backspace
                       8'h66: data_q <= "\010";
                       // space
                       8'h29: data_q <= " ";
                       // return
                       8'h5a: data_q <= "\r";
                       // shifts
                       8'h12: begin
                          lshift_pressed <= 1;
                          valid_q <= 0;
                          // XXX this will not clear the char, maybe use a flag reg for this,
                          // like char processed, instead of relying on new_char_wen &
                          // // write_cursor_pos
                       end
                       8'h59: begin
                          rshift_pressed <= 1;
                          valid_q <= 0;
                          // XXX this will not clear the char, maybe use a flag reg for this,
                          // like char processed, instead of relying on new_char_wen &
                          // // write_cursor_pos
                       end
                       // caps lock
                       8'h58: begin
                          // TODO caps lock
                       end
                       default: begin
                          valid_q <= 0;
                       end
                     endcase // case (ps2_byte)
                  end // else: !if(lshift_pressed || rshift_pressed)
               end // else: !if(ps2_long_keycode)
            end // else: !if(ps2_break_keycode)
         end // if (!write_cursor_pos && !new_char_wen)
      end // else: !if(clr)
   end // always @ (posedge clk or posedge clr)
endmodule
