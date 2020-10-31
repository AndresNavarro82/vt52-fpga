// TODO add 1k of keymap ROM and move all logic
// to the rom (shift/meta/control/caps lock/spacial keys)
// encode keytype in the rom:
// 0xxxxxxx: regular ASCII key
// 10xxxxxx: control/meta/shift or caps lock, each bit is a key, all 0 for caps lock
// 11xxxxxx: special key, ESC + upper case ASCII (clear msb to get char)
module keyboard
  (input  clk,
   input  reset,
   input  ps2_data,
   input  ps2_clk,
   output reg [7:0] data,
   output reg valid,
   input ready
   );

   // state: one hot encoding
   // idle is the normal state, reading the ps/2 bus
   // key up/down (long and short) are for key events
   // keymap_read is for reading the keymap rom
   // esc_char is for sending ESC- prefixed chars
   localparam state_idle           = 8'b00000001;
   localparam state_long_key_down  = 8'b00000010;
   localparam state_short_key_down = 8'b00000100;
   localparam state_long_key_up    = 8'b00001000;
   localparam state_short_key_up   = 8'b00010000;
   localparam state_keymap_read    = 8'b00100000;
   localparam state_esc_char       = 8'b01000000;
   localparam esc = 8'h1b;

   reg [7:0] state;

   reg [1:0] ps2_old_clks;
   reg [10:0] ps2_raw_data;
   reg [3:0]  ps2_count;
   reg [7:0]  ps2_byte;
   // we are processing a break_code (key up)
   reg ps2_break_keycode;
   // we are processing a long keycode (two bytes)
   reg ps2_long_keycode;
   // shift key status
   reg lshift_pressed;
   reg rshift_pressed;
   wire shift_pressed = lshift_pressed || rshift_pressed;
   // control key status
   reg lcontrol_pressed;
   reg rcontrol_pressed;
   wire control_pressed = lcontrol_pressed || rcontrol_pressed;
   // alt/meta key status (vt52 doesn't have meta, but I want to use
   // emacs & can't stand that Esc- business...)
   reg lmeta_pressed;
   reg rmeta_pressed;
   wire meta_pressed = lmeta_pressed || rmeta_pressed;
   // caps lock
   reg caps_lock_active;
   // keymap
   wire [9:0] keymap_address;
   wire [7:0] keymap_data;
   // special char to send after ESC
   reg [7:0] special_data;

   // ps2_byte is the actual keycode, we use caps lock & shift to
   // determine the plane we need
   assign keymap_address = { caps_lock_active, shift_pressed, ps2_byte };

   keymap_rom keymap_rom(.clk(clk),
                         .addr(keymap_address),
                         .dout(keymap_data)
                         );

   // we don't need to do this on the pixel clock, we could use
   // something way slower, but it works
   always @(posedge clk) begin
      if (reset) begin
         state <= state_idle;

         data <= 0;
         valid <= 0;

         // the clk is usually high and pulled down to start
         ps2_old_clks <= 2'b00;
         ps2_raw_data <= 0;
         ps2_count <= 0;
         ps2_byte <= 0;

         ps2_break_keycode <= 0;
         ps2_long_keycode <= 0;

         lshift_pressed <= 0;
         rshift_pressed <= 0;
         lcontrol_pressed <= 0;
         rcontrol_pressed <= 0;
         lmeta_pressed <= 0;
         rmeta_pressed <= 0;
         caps_lock_active <= 0;

         special_data <= 0;
      end
      else if (valid && ready) begin
         valid <= 0;
         ps2_break_keycode <= 0;
         ps2_long_keycode <= 0;
         ps2_byte <= 0;
      end
      else begin
        case (state)
          state_idle: begin
             ps2_old_clks <= {ps2_old_clks[0], ps2_clk};

             if(ps2_clk && ps2_old_clks == 2'b01) begin
                // clock edge detected, read another bit
                if(ps2_count == 10) begin
                   // 11 bits means we are done (XXX/TODO check parity and stop bits)
                   ps2_count <= 0;
                   ps2_byte <= ps2_raw_data[10:3];
                   // handle the breaks & long keycodes and only change to
                   // keycode state if a complete keycode is already received
                   if (ps2_raw_data[10:3] == 8'he0) begin
                      ps2_break_keycode <= 0;
                      ps2_long_keycode <= 1;
                   end
                   else if (ps2_raw_data[10:3] == 8'hf0) begin
                      ps2_break_keycode <= 1;
                   end
                   else if (ps2_byte != 8'he0 && ps2_byte != 8'hf0) begin
                      ps2_break_keycode <= 0;
                      ps2_long_keycode <= 0;
                      state <= state_short_key_down;
                   end
                   else if (ps2_break_keycode) begin
                      state <= ps2_long_keycode? state_long_key_up : state_short_key_up;
                   end
                   else begin
                      state <= ps2_long_keycode? state_long_key_down : state_short_key_down;
                   end
                end
                else begin
                   // the data comes lsb first
                   ps2_raw_data <= {ps2_data, ps2_raw_data[10:1]};
                   ps2_count <= ps2_count + 1;
                end
             end
          end
          state_long_key_up: begin
             // we only care about the shift, control and meta states
             state <= state_idle;
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             if (ps2_byte == 8'h14) begin
                rcontrol_pressed <= 0;
             end
             else if (ps2_byte == 8'h11) begin
                rmeta_pressed <= 0;
             end
          end
          state_short_key_up: begin
             // we only care about the shift, control and meta states
             state <= state_idle;
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             if (ps2_byte == 8'h12) begin
                lshift_pressed <= 0;
             end
             else if (ps2_byte == 8'h59) begin
                rshift_pressed <= 0;
             end
             else if (ps2_byte == 8'h14) begin
                lcontrol_pressed <= 0;
             end
             else if (ps2_byte == 8'h11) begin
                lmeta_pressed <= 0;
             end
          end
          state_long_key_down: begin
             // we care about the shift, control and meta states
             // and also arrows, del & insert (line feed)
             state <= state_idle;
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             if (ps2_byte == 8'h14) begin
                rcontrol_pressed <= 1;
             end
             else if (ps2_byte == 8'h11) begin
                rmeta_pressed <= 1;
             end
             else if (ps2_byte == 8'h71) begin
                // DEL key, send either DEL or US (if control pressed)
                data <= {
                         1'b0,
                         control_pressed? 2'b00 : 2'b11,
                         5'b11111
                         };
                valid <= 1;
             end
             else if (ps2_byte == 8'h70) begin
                // INS key, send line feed char
                data <= 8'h0a;
                valid <= 1;
             end
             else if (ps2_byte == 8'h75) begin
                // up arrow, send either Esc-A or Esc-C^A (if control pressed)
                data <= esc;
                valid <= 1;
                state <= state_esc_char;
                special_data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : 2'b11,
                                 5'b00001
                                };
             end
             else if (ps2_byte == 8'h72) begin
                // down arrow, send either Esc-B or Esc-C^B (if control pressed)
                data <= esc;
                valid <= 1;
                state <= state_esc_char;
                special_data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : 2'b11,
                                 5'b00010
                                 };
             end
             else if (ps2_byte == 8'h74) begin
                // right arrow, send either Esc-C or Esc-C^C (if control pressed)
                data <= esc;
                valid <= 1;
                state <= state_esc_char;
                special_data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : 2'b11,
                                 5'b00011
                                 };
             end
             else if (ps2_byte == 8'h6b) begin
                // left arrow, send either Esc-d Esc-C^D (if control pressed)
                data <= esc;
                valid <= 1;
                state <= state_esc_char;
                special_data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : 2'b11,
                                 5'b00100
                                 };
             end
          end
          state_short_key_down: begin
             // default value, may be overridden
             state <= state_idle;
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             if (ps2_byte == 8'h12) begin
                lshift_pressed <= 1;
             end
             else if (ps2_byte == 8'h59) begin
                rshift_pressed <= 1;
             end
             if (ps2_byte == 8'h14) begin
                lcontrol_pressed <= 1;
             end
             else if (ps2_byte == 8'h11) begin
                lmeta_pressed <= 1;
             end
             else if (ps2_byte == 8'h58) begin
                caps_lock_active <= ~caps_lock_active;
             end
             else if (ps2_byte == 8'h05) begin
                // F1, map to left blank key: Esc-P
                state <= state_esc_char;
                special_data <= "P";
                data <= esc;
                valid <= 1;
             end
             else if (ps2_byte == 8'h06) begin
                // F1, map to center blank key: Esc-Q
                state <= state_esc_char;
                special_data <= "Q";
                data <= esc;
                valid <= 1;
             end
             else if (ps2_byte == 8'h04) begin
                // F1, map to right blank key: Esc-R
                state <= state_esc_char;
                special_data <= "R";
                data <= esc;
                valid <= 1;
             end
             else begin
                // regular keys, read from keymap ROM
                state <= state_keymap_read;
             end
          end
          state_keymap_read: begin
             state <= state_idle;
             if (keymap_data != 0) begin
                // apply modifier keys
                // meta turns on the 8th bit
                // control turns off 7th & 6th bits
                data <= {
                         meta_pressed,
                         control_pressed? 2'b00 : keymap_data[6:5],
                         keymap_data[4:0]
                        };
                valid <= 1;
             end
          end
          state_esc_char: begin
             // only send special char after ESC was successfully sent
             if (valid == 0) begin
                state <= state_idle;
                data <= {
                         1'b0,
                         control_pressed? 2'b00 : special_data[6:5],
                         special_data[4:0]
                         };
                valid <= 1;
             end
          end
        endcase // case (state)
      end // else: !if(valid && ready)
   end // always @ (posedge clk)
endmodule
