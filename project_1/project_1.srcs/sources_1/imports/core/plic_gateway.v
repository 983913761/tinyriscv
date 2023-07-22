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


module plic_gateway#(
  parameter ID = 4'd1
)(
    input  clk,
    input  rst_n,

    input  src_i,   //输入中断源
    input  req_complete_i,  //表示中断完成
    output reg req_o,
    output id_o
    );
    
    assign id_o = ID;
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
