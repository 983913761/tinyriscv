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

// ȡָģ��
module ifu(

    input wire clk,
    input wire rst_n,

    input wire flush_i,
    input wire[31:0] flush_addr_i,             // ��ת��ַ
    input wire[`STALL_WIDTH-1:0] stall_i,      // ��ˮ����ͣ��־
    input wire jtag_halt_i,

    output wire[31:0] inst_o,
    output wire[31:0] pc_o,
    output wire inst_valid_o,

    output wire[31:0] ibus_addr_o,
    input wire[31:0] ibus_data_i,
    output wire[31:0] ibus_data_o,
    output wire[3:0] ibus_sel_o,
    output wire ibus_we_o,
    output wire req_valid_o,
    input wire req_ready_i,
    input wire rsp_valid_i,
    output wire rsp_ready_o

    );

    assign req_valid_o = (~rst_n)? 1'b0:
                         (flush_i)? 1'b0:
                         stall_i[`STALL_PC]? 1'b0:
                         jtag_halt_i? 1'b0:
                         1'b1;
    assign rsp_ready_o = (~rst_n)? 1'b0: 1'b1;

    wire ifu_req_hsked = (req_valid_o & req_ready_i);
    wire ifu_rsp_hsked = (rsp_valid_i & rsp_ready_o);

    // ��ִ�ж�����ָ��������󲻵�����ʱ��Ҫ��ͣ
    wire stall = stall_i[`STALL_PC] | (~ifu_req_hsked);

    reg[31:0] pc;
    reg[31:0] pc_prev;

    always @ (posedge clk or negedge rst_n) begin
        // ��λ
        if (!rst_n) begin
            pc <= `CPU_RESET_ADDR;
            pc_prev <= 32'h0;
        // ��ˢ
        end else if (flush_i) begin
            pc <= flush_addr_i;
        // ��ͣ��ȡ��һ��ָ��
        end else if (stall) begin
            pc <= pc_prev;
        // ȡ��һ��ָ��
        end else begin
            pc <= pc + 32'h4;
            pc_prev <= pc;
        end
    end

    wire[31:0] pc_r;
    // ��PC��һ��
    wire pc_ena = (~stall);
    gen_en_dff #(32) pc_dff(clk, rst_n, pc_ena, pc, pc_r);

    reg req_hasked_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_hasked_r <= 1'b1;
        end else begin
            req_hasked_r <= ifu_req_hsked;
        end
    end

    wire req_switched = ifu_req_hsked & (~req_hasked_r);

    reg rsp_hasked_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_hasked_r <= 1'b1;
        end else begin
            rsp_hasked_r <= ifu_rsp_hsked;
        end
    end

    wire rsp_switched = ifu_rsp_hsked & (~rsp_hasked_r);

    // �����л������������
    // 1.�ô��ַλ��ָ��洢�������ô���ɺ�ifu_req_hsked��ifu_rsp_hsked�źŻ�ͬʱ��0��Ϊ1
    // 2.�ô��ַ��λ��ָ��洢�������ô���ɺ�ifu_req_hsked�ȴ�0��Ϊ1��ifu_rsp_hsked���0��Ϊ1
    // ֻ�е�2�������ȡ������ָ������Ч�ģ�����Ҫ�����������ʶ�����
    wire bus_switched = req_switched & rsp_switched;

    // ȡָ��ַ
    assign ibus_addr_o = pc;
    assign pc_o = pc_r;
    wire inst_valid = ifu_rsp_hsked & (~flush_i) & (~bus_switched);
    assign inst_o = inst_valid? ibus_data_i: `INST_NOP;

    assign ibus_sel_o = 4'b1111;
    assign ibus_we_o = 1'b0;
    assign ibus_data_o = 32'h0;

endmodule
