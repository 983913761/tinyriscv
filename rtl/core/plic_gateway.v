`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/20 18:53:30
// Design Name: 
// Module Name: plic_gateway
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module plic_gateway(
    input  clk,
    input  rst_n,

    input  src_i,   
    input  req_complete_i, 
    output reg req_o
    );
    reg src_delay;
    
    wire set = src_i & (~src_delay);
    
    always @(posedge clk, negedge rst_n) begin
      if (!rst_n)begin
        src_delay <= 1'b0;
      end else begin
              src_delay <= src_i;
          end
    end
    
      always @(posedge clk, negedge rst_n) begin
          if (!rst_n)begin
            req_o <= 1'b0;
          end else if(req_complete_i) begin
                  req_o <= 1'b0;
              end else if(set) begin
                        req_o <= 1'b1;
                    end else begin
                            req_o <= req_o;
                        end
              
        end
    
    
endmodule
