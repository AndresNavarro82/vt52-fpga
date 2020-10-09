/**
 * Led counter to see the sync signals at an appropriate speed
 */
module led_counter(
                   input wire  clk_in,
                   output wire led_out
                   );

   reg [9:0] counter = 10'b0;
   assign led = counter[9];
   always @(posedge clk_in)
     begin
        counter <= counter + 1;
     end
endmodule

