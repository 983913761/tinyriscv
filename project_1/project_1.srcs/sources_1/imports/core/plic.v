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

module plic(

    input wire clk,
    input wire rst_n,

    // from GPIO
    input wire[1:0] exti_flag_i,      // �ж������ź�

    // from exu
//    input wire inst_ecall_i,                    // ecallָ��
//    input wire inst_ebreak_i,                   // ebreakָ��
//    input wire inst_mret_i,                     // mretָ��
    input wire[31:0] inst_addr_i,               // ָ���ַ
//    input wire jump_flag_i,
//    input wire mem_access_misaligned_i,

    // from csr_reg
    input wire[31:0] csr_mtvec_i,               // mtvec�Ĵ���
    input wire[31:0] csr_mepc_i,                // mepc�Ĵ���
    input wire[31:0] csr_mstatus_i,             // mstatus�Ĵ���

    // to csr_reg
    output reg csr_we_o,                        // дCSR�Ĵ�����־
    output reg[31:0] csr_waddr_o,               // дCSR�Ĵ�����ַ
    output reg[31:0] csr_wdata_o,               // дCSR�Ĵ�������

    // to pipe_ctrl
    output wire stall_flag_o,                   // ��ˮ����ͣ��־
    output wire[31:0] int_addr_o,               // �ж���ڵ�ַ
    output wire int_assert_o                    // �жϱ�־

    );

    // �ж�״̬����
    localparam S_INT_IDLE            = 4'b0001;
    localparam S_INT_EXIT_ASSERT     = 4'b0010;

    // дCSR�Ĵ���״̬����
    localparam S_CSR_IDLE            = 4'b0001;
    localparam S_CSR_MSTATUS         = 4'b0010;
    localparam S_CSR_MEPC            = 4'b0100;
    localparam S_CSR_MCAUSE          = 4'b1000;

    reg[3:0] int_state;
    reg[3:0] csr_state;
    reg[31:0] inst_addr;
    reg[31:0] cause;
    
    wire exti_req_0;
    wire exti_req_1;
    wire exti_ID_0;
    wire exti_ID_1;

    wire Exit_ID;//�жϵ����

    wire global_int_en = csr_mstatus_i[3];//mstatus�ĵ���λ������ȫ���ж�ʹ��

    assign stall_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE))? 1'b1: 1'b0;//��csr�Ĵ������߼�⵽�ж�ʱ��ͣ��ˮ��

    // ����ת��־������ˮ���ϴ���
//    wire pc_state_jump_flag;
//    gen_rst_0_dff #(1) pc_state_dff(clk, rst_n, jump_flag_i, pc_state_jump_flag);

//    wire if_state_jump_flag;
//    gen_rst_0_dff #(1) if_state_dff(clk, rst_n, pc_state_jump_flag, if_state_jump_flag);

//    wire id_state_jump_flag;
//    gen_rst_0_dff #(1) id_state_dff(clk, rst_n, if_state_jump_flag, id_state_jump_flag);

//    wire ex_state_jump_flag;
//    gen_rst_0_dff #(1) ex_state_dff(clk, rst_n, id_state_jump_flag, ex_state_jump_flag);

//    wire[3:0] state_jump_flag = {pc_state_jump_flag, if_state_jump_flag, id_state_jump_flag, ex_state_jump_flag};
//    // �����ˮ��û�г�ˢ�������Ӧ�ж�
//    wire inst_addr_valid = (~(|state_jump_flag)) | ex_state_jump_flag;


    // �ж��ٲ��߼�
    always @ (*) begin
        // �ⲿ�ж�
        if (exti_req_0 | exti_req_1) begin
            int_state = S_INT_EXIT_ASSERT;
        // ���ж���Ӧ
        end else begin
            int_state = S_INT_IDLE;
        end
    end

    // дCSR�Ĵ���״̬�л�
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_state <= S_CSR_IDLE;
            cause <= 32'h0;
            inst_addr <= 32'h0;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    case (int_state)
                        // �ⲿ�ж�
                        S_INT_EXIT_ASSERT: begin
                            csr_state <= S_CSR_MEPC;
                            // ���жϴ�������Ὣ�жϷ��ص�ַ��4
                            inst_addr <= inst_addr_i;
                            cause <= 32'd11;
                        end
                    endcase
                end
                S_CSR_MEPC: begin
                    csr_state <= S_CSR_MSTATUS;
                end
                S_CSR_MSTATUS: begin
                    csr_state <= S_CSR_MCAUSE;
                end
                S_CSR_MCAUSE: begin
                    csr_state <= S_CSR_IDLE;
                end
                
                default: begin
                    csr_state <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // �����ж��ź�ǰ����д����CSR�Ĵ���
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_we_o <= 1'b0;
            csr_waddr_o <= 32'h0;
            csr_wdata_o <= 32'h0;
        end else begin
            case (csr_state)
                // ��mepc�Ĵ�����ֵ��Ϊ��ǰָ���ַ
                S_CSR_MEPC: begin
                    csr_we_o <= 1'b1;
                    csr_waddr_o <= {20'h0, `CSR_MEPC};
                    csr_wdata_o <= inst_addr;
                end
                // д�жϲ�����ԭ��
                S_CSR_MCAUSE: begin
                    csr_we_o <= 1'b1;
                    csr_waddr_o <= {20'h0, `CSR_MCAUSE};
                    csr_wdata_o <= cause;
                end
                // �ر�ȫ���ж�
                S_CSR_MSTATUS: begin
                    csr_we_o <= 1'b1;
                    csr_waddr_o <= {20'h0, `CSR_MSTATUS};
                    csr_wdata_o <= {csr_mstatus_i[31:4], 1'b0, csr_mstatus_i[2:0]};
                end

                default: begin
                    csr_we_o <= 1'b0;
                    csr_waddr_o <= 32'h0;
                    csr_wdata_o <= 32'h0;
                end
            endcase
        end
    end

    assign int_assert_o = (csr_state == S_CSR_MCAUSE);
    
    assign Exit_ID =    exti_req_0? exti_ID_0:
                        exti_req_1? exti_ID_1:
                        1'b0;        
    assign int_addr_o = (csr_state == S_CSR_MCAUSE)? `PLIC_ADDR_BASE + (3'd4 * Exit_ID):
                        32'h0;

    plic_gateway#(
    .ID(4'd0)
    )plic_gateway_0(
    .clk(clk),
    .rst_n(rst_n),
    .src_i(exti_flag_i[0]),   //�����ж�Դ
    .req_complete_i(int_assert_o),  //��ʾ�ж����
    .req_o(exti_req_0),
    .id_o(exti_ID_0)
    );

    plic_gateway#(
    .ID(4'd1)
    )plic_gateway_1(
    .clk(clk),
    .rst_n(rst_n),
    .src_i(exti_flag_i[1]),   //�����ж�Դ
    .req_complete_i(int_assert_o),  //��ʾ�ж����
    .req_o(exti_req_1),
    .id_o(exti_ID_1)
    );
endmodule
