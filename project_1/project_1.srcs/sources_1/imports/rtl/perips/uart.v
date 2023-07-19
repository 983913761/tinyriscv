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

`include "../core/defines.v"

// �����շ�ģ��(Ĭ��: 115200, 8��N��1)
module uart(

    input wire clk,
    input wire rst_n,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire[3:0] sel_i,
    input wire we_i,
	output wire[31:0] data_o,

    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,

	output wire tx_pin,
    input wire rx_pin

    );

    // ������115200bps
    localparam BAUD_115200 = `CPU_CLOCK_HZ / 115200;

    localparam S_IDLE       = 4'b0001;
    localparam S_START      = 4'b0010;
    localparam S_SEND_BYTE  = 4'b0100;
    localparam S_STOP       = 4'b1000;


    reg[3:0] state;
    reg[3:0] next_state;
    reg[15:0] cycle_cnt;
    reg tx_bit;
    reg[3:0] bit_cnt;

    reg rx_q0;
    reg rx_q1;
    wire rx_negedge;
    reg rx_start;                      // RXʹ��
    reg[3:0] rx_clk_edge_cnt;          // clk�صĸ���
    reg rx_clk_edge_level;             // clk�ص�ƽ
    reg rx_done;
    reg[15:0] rx_clk_cnt;
    reg[15:0] rx_div_cnt;
    reg[7:0] rx_data;
    reg rx_over;

    // �Ĵ���(ƫ��)��ַ
    localparam UART_CTRL    = 8'h0;
    localparam UART_STATUS  = 8'h4;
    localparam UART_BAUD    = 8'h8;
    localparam UART_TXDATA  = 8'hc;
    localparam UART_RXDATA  = 8'h10;

    // UART���ƼĴ������ɶ���д
    // bit[0]: UART TXʹ��, 1: enable, 0: disable
    // bit[1]: UART RXʹ��, 1: enable, 0: disable
    reg[31:0] uart_ctrl;

    // UART״̬�Ĵ���
    // ֻ����bit[0]: TX����״̬��־, 1: busy, 0: idle
    // �ɶ���д��bit[1]: RX������ɱ�־, 1: over, 0: receiving
    reg[31:0] uart_status;

    // UART�����ʼĴ���(��Ƶϵ��)���ɶ���д
    reg[31:0] uart_baud;

    // UART�������ݼĴ������ɶ���д
    reg[31:0] uart_tx;

    // UART�������ݼĴ�����ֻ��
    reg[31:0] uart_rx;

    wire wen = we_i & req_valid_i;
    wire ren = (~we_i) & req_valid_i;
    wire write_reg_ctrl_en = wen & (addr_i[7:0] == UART_CTRL);
    wire write_reg_status_en = wen & (addr_i[7:0] == UART_STATUS);
    wire write_reg_baud_en = wen & (addr_i[7:0] == UART_BAUD);
    wire write_reg_txdata_en = wen & (addr_i[7:0] == UART_TXDATA);
    wire tx_start = write_reg_txdata_en & sel_i[0] & uart_ctrl[0] & (~uart_status[0]);
    wire rx_recv_over = uart_ctrl[1] & rx_over;

    assign tx_pin = tx_bit;


    // дuart_rxdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx <= 32'h0;
        end else begin
            // �������ʱ��������յ�������
            if (rx_recv_over) begin
                uart_rx[7:0] <= rx_data;
            end
        end
    end

    // дuart_txdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx <= 32'h0;
        end else begin
            // ��ʼ����ʱ������Ҫ���͵�����
            if (tx_start) begin
                uart_tx[7:0] <= data_i[7:0];
            end
        end
    end

    // дuart_status
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_status <= 32'h0;
        end else begin
            if (write_reg_status_en & sel_i[0]) begin
                // дRX��ɱ�־
                uart_status[1] <= data_i[1];
            end else begin
                // ��ʼ��������ʱ����λTXæ��־
                if (tx_start) begin
                    uart_status[0] <= 1'b1;
                // �������ʱ����TXæ��־
                end else if ((state == S_STOP) & (cycle_cnt == uart_baud[15:0])) begin
                    uart_status[0] <= 1'b0;
                // ������ɣ���λ������ɱ�־
                end
                if (rx_recv_over) begin
                    uart_status[1] <= 1'b1;
                end
            end
        end
    end

    // дuart_ctrl
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ctrl <= 32'h0;
        end else begin
            if (write_reg_ctrl_en & sel_i[0]) begin
                uart_ctrl[7:0] <= data_i[7:0];
            end
        end
    end

    // дuart_baud
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_baud <= BAUD_115200;
        end else begin
            if (write_reg_baud_en) begin
                if (sel_i[0]) begin
                    uart_baud[7:0] <= data_i[7:0];
                end
                if (sel_i[1]) begin
                    uart_baud[15:8] <= data_i[15:8];
                end
            end
        end
    end

    reg[31:0] data_r;

    // ���Ĵ���
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_r <= 32'h0;
        end else begin
            if (ren) begin
                case (addr_i[7:0])
                    UART_CTRL:   data_r <= uart_ctrl;
                    UART_STATUS: data_r <= uart_status;
                    UART_BAUD:   data_r <= uart_baud;
                    UART_RXDATA: data_r <= uart_rx;
                    default:     data_r <= 32'h0;
                endcase
            end else begin
                data_r <= 32'h0;
            end
        end
    end

    assign data_o = data_r;

    // *************************** TX���� ****************************

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @ (*) begin
        case (state)
            S_IDLE: begin
                if (tx_start) begin
                    next_state = S_START;
                end else begin
                    next_state = S_IDLE;
                end
            end
            S_START: begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    next_state = S_SEND_BYTE;
                end else begin
                    next_state = S_START;
                end
            end
            S_SEND_BYTE: begin
                if ((cycle_cnt == uart_baud[15:0]) & (bit_cnt == 4'd7)) begin
                    next_state = S_STOP;
                end else begin
                    next_state = S_SEND_BYTE;
                end
            end
            S_STOP: begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = S_STOP;
                end
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // cycle_cnt
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 16'h0;
        end else begin
            if (state == S_IDLE) begin
                cycle_cnt <= 16'h0;
            end else begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    cycle_cnt <= 16'h0;
                end else begin
                    cycle_cnt <= cycle_cnt + 16'h1;
                end
            end
        end
    end

    // bit_cnt
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 4'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    bit_cnt <= 4'h0;
                end
                S_SEND_BYTE: begin
                    if (cycle_cnt == uart_baud[15:0]) begin
                        bit_cnt <= bit_cnt + 4'h1;
                    end
                end
            endcase
        end
    end

    // tx_bit
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_bit <= 1'b0;
        end else begin
            case (state)
                S_IDLE, S_STOP: begin
                    tx_bit <= 1'b1;
                end
                S_START: begin
                    tx_bit <= 1'b0;
                end
                S_SEND_BYTE: begin
                    tx_bit <= uart_tx[bit_cnt];
                end
            endcase
        end
    end

    // *************************** RX���� ****************************

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_q0 <= 1'b0;
            rx_q1 <= 1'b0;	
        end else begin
            rx_q0 <= rx_pin;
            rx_q1 <= rx_q0;
        end
    end

    // �½��ؼ��(�����ʼ�ź�)
    assign rx_negedge = rx_q1 & (~rx_q0);

    // ������ʼ���������źţ������ڼ�һֱ��Ч
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_start <= 1'b0;
        end else begin
            if (uart_ctrl[1]) begin
                if (rx_negedge) begin
                    rx_start <= 1'b1;
                end else if (rx_clk_edge_cnt == 4'd9) begin
                    rx_start <= 1'b0;
                end
            end else begin
                rx_start <= 1'b0;
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_div_cnt <= 16'h0;
        end else begin
            // ��һ��ʱ����ֻ�貨���ʷ�Ƶϵ����һ��
            if (rx_start == 1'b1 && rx_clk_edge_cnt == 4'h0) begin
                rx_div_cnt <= {1'b0, uart_baud[15:1]};
            end else begin
                rx_div_cnt <= uart_baud[15:0];
            end
        end
    end

    // ��ʱ�ӽ��м���
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_cnt <= 16'h0;
        end else if (rx_start == 1'b1) begin
            // �����ﵽ��Ƶֵ
            if (rx_clk_cnt == rx_div_cnt) begin
                rx_clk_cnt <= 16'h0;
            end else begin
                rx_clk_cnt <= rx_clk_cnt + 16'h1;
            end
        end else begin
            rx_clk_cnt <= 16'h0;
        end
    end

    // ÿ��ʱ�Ӽ����ﵽ��Ƶֵʱ����һ������������
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end else if (rx_start == 1'b1) begin
            // �����ﵽ��Ƶֵ
            if (rx_clk_cnt == rx_div_cnt) begin
                // ʱ���ظ����ﵽ���ֵ
                if (rx_clk_edge_cnt == 4'd9) begin
                    rx_clk_edge_cnt <= 4'h0;
                    rx_clk_edge_level <= 1'b0;
                end else begin
                    // ʱ���ظ�����1
                    rx_clk_edge_cnt <= rx_clk_edge_cnt + 4'h1;
                    // ��������������
                    rx_clk_edge_level <= 1'b1;
                end
            end else begin
                rx_clk_edge_level <= 1'b0;
            end
        end else begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end
    end

    // bit����
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h0;
            rx_over <= 1'b0;
        end else begin
            if (rx_start == 1'b1) begin
                // ������
                if (rx_clk_edge_level == 1'b1) begin
                    case (rx_clk_edge_cnt)
                        // ��ʼλ
                        1: begin

                        end
                        // ��1λ����λ
                        2: begin
                            if (rx_pin) begin
                                rx_data <= 8'h80;
                            end else begin
                                rx_data <= 8'h0;
                            end
                        end
                        // ʣ������λ
                        3, 4, 5, 6, 7, 8, 9: begin
                            rx_data <= {rx_pin, rx_data[7:1]};
                            // ���һλ������ɣ���λ������ɱ�־
                            if (rx_clk_edge_cnt == 4'h9) begin
                                rx_over <= 1'b1;
                            end
                        end
                    endcase
                end
            end else begin
                rx_data <= 8'h0;
                rx_over <= 1'b0;
            end
        end
    end

    vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst_n),
        .vld_i(req_valid_i),
        .rdy_o(req_ready_o),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

endmodule
