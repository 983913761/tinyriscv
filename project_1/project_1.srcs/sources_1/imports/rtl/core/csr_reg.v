 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "defines.v"

// CSR�Ĵ���ģ��
module csr_reg(

    input wire clk,
    input wire rst_n,

    // exu
    input wire exu_we_i,                    // exuģ��д�Ĵ�����־
    input wire[31:0] exu_waddr_i,           // exuģ��д�Ĵ�����ַ
    input wire[31:0] exu_wdata_i,           // exuģ��д�Ĵ�������
    input wire[31:0] exu_raddr_i,           // exuģ����Ĵ�����ַ
    output wire[31:0] exu_rdata_o,          // exuģ����Ĵ�������

    // clint
    input wire clint_we_i,                  // clintģ��д�Ĵ�����־
    input wire[31:0] clint_waddr_i,         // clintģ��д�Ĵ�����ַ
    input wire[31:0] clint_wdata_i,         // clintģ��д�Ĵ�������
    
    //plic
    input wire plic_we_i,                  // clintģ��д�Ĵ�����־
    input wire[31:0] plic_waddr_i,         // clintģ��д�Ĵ�����ַ
    input wire[31:0] plic_wdata_i,         // clintģ��д�Ĵ�������
    
    output wire[31:0] mtvec_o,              // mtvec�Ĵ���ֵ
    output wire[31:0] mepc_o,               // mepc�Ĵ���ֵ
    output wire[31:0] mstatus_o             // mstatus�Ĵ���ֵ

    );

    reg[63:0] cycle;
    reg[31:0] mtvec;
    reg[31:0] mcause;
    reg[31:0] mepc;
    reg[31:0] mie;
    reg[31:0] mstatus;
    reg[31:0] mscratch;

    assign mtvec_o = mtvec;
    assign mepc_o = mepc;
    assign mstatus_o = mstatus;

    // cycle counter
    // ��λ�������һֱ����
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle <= {32'h0, 32'h0};
        end else begin
            cycle <= cycle + 1'b1;
        end
    end

    wire we = exu_we_i | clint_we_i | plic_we_i;
    wire[31:0] waddr = exu_we_i? exu_waddr_i: 
                        clint_we_i ? clint_waddr_i:
                        plic_waddr_i;
                        
    wire[31:0] wdata = exu_we_i? exu_wdata_i:
                        clint_we_i? clint_wdata_i:
                        plic_wdata_i;

    // д�Ĵ���
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtvec <= 32'h0;
            mcause <= 32'h0;
            mepc <= 32'h0;
            mie <= 32'h0;
            mstatus <= 32'h0;
            mscratch <= 32'h0;
        end else begin
            if (we) begin
                case (waddr[11:0])
                    `CSR_MTVEC: begin
                        mtvec <= wdata;
                    end
                    `CSR_MCAUSE: begin
                        mcause <= wdata;
                    end
                    `CSR_MEPC: begin
                        mepc <= wdata;
                    end
                    `CSR_MIE: begin
                        mie <= wdata;
                    end
                    `CSR_MSTATUS: begin
                        mstatus <= wdata;
                    end
                    `CSR_MSCRATCH: begin
                        mscratch <= wdata;
                    end
                endcase
            end
        end
    end

    reg[31:0] exu_rdata;

    // exuģ���CSR�Ĵ���
    always @ (*) begin
        case (exu_raddr_i[11:0])
            `CSR_CYCLE: begin
                exu_rdata = cycle[31:0];
            end
            `CSR_CYCLEH: begin
                exu_rdata = cycle[63:32];
            end
            `CSR_MTVEC: begin
                exu_rdata = mtvec;
            end
            `CSR_MCAUSE: begin
                exu_rdata = mcause;
            end
            `CSR_MEPC: begin
                exu_rdata = mepc;
            end
            `CSR_MIE: begin
                exu_rdata = mie;
            end
            `CSR_MSTATUS: begin
                exu_rdata = mstatus;
            end
            `CSR_MSCRATCH: begin
                exu_rdata = mscratch;
            end
            default: begin
                exu_rdata = 32'h0;
            end
        endcase
    end

    assign exu_rdata_o = exu_rdata;

endmodule
