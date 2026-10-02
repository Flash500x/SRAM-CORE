`timescale 1ns / 1ps

module arbiter(
input wire a,b,clk,rst,
output reg rg,wg,busy
    );
        reg p;
        always @(posedge clk or negedge rst)
        begin
            if(!rst)
                begin
                    p <= 1'b1;
                    rg <= 1'b0;
                    wg <= 1'b0;
                end
            else
                begin  
                    rg <= 1'b0;
                    wg <= 1'b0;
                
                    begin
                    if(a && b)
                    begin
                        if(p)
                        begin
                            wg <= 1'b1;
                            rg <= 1'b0;
                             p  <= 1'b0;
                        end
                        else
                            begin
                            wg <= 1'b0;
                            rg <= 1'b1;
                             p  <= 1'b1;
                            end
                    end
                    else if (a) 
                    begin
                            rg <= 1'b1;
                            p  <= 1'b1;
                    end
                    else if (b) begin
                            wg <= 1'b1;
                            p  <= 1'b0;
                    end
                  end  
            end
            end
            
            always @(negedge b or negedge a)
            begin
                wg <= 1'b0;
                rg <= 1'b0;
            end
endmodule
