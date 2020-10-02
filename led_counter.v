/**
 * Led counter to see the sync signals at an appropriate speed
 */
module led_counter(
                   input wire        clk_in,
                   output wire [4:0] led_out
                   );

   reg [9:0]                         counter = 10'b0;
   always @(posedge clk_in)
     begin
        counter <= counter + 1;
     end
   assign led_out = counter[9:5];
endmodule

