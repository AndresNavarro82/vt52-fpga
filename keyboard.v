// TODO define constants for the control codes
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
   localparam state_idle           = 8'b00000001;
   localparam state_long_key_down  = 8'b00000010;
   localparam state_short_key_down = 8'b00000100;
   localparam state_long_key_up    = 8'b00001000;
   localparam state_short_key_up   = 8'b00010000;
   localparam state_keymap_read    = 8'b00100000;
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

   // ps2_byte is the actual keycode, we use caps lock & shift to
   // determine the plane we need
   assign keymap_address = { caps_lock_active, shift_pressed, ps2_byte };
//   keymap_rom keymap_rom(keymap_address, clk, keymap_data);
   keymap_rom keymap_rom(keymap_address, clk, keymap_data);

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
             // we only care about the shift, control and meta states
             state <= state_idle;
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             if (ps2_byte == 8'h14) begin
                rcontrol_pressed <= 1;
             end
             else if (ps2_byte == 8'h11) begin
                rmeta_pressed <= 1;
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
        endcase // case (state)
      end // else: !if(valid && ready)
   end // always @ (posedge clk)
endmodule
