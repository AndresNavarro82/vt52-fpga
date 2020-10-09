module clock_divider(
                     input fast_clk,
                     input clr,
                     output reg slow_clk
                     );

   always @(posedge fast_clk or posedge clr) begin
        if (clr == 1) begin
           slow_clk <= 0;
        end
        else begin
          slow_clk <= ~slow_clk;
        end
   end
endmodule
