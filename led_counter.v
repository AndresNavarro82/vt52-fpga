/**
 * Led counter to see the sync signals at an appropriate speed
 */
module led_counter(
                   input wire  clk_in,
                   output wire led_out
                   );

   reg [5:0] counter = 6'b0;
   assign led_out = counter[5];
   always @(posedge clk_in)
     begin
        counter <= counter + 1;
     end
endmodule

