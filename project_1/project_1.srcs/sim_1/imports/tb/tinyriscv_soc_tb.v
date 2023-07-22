`timescale 1 ns / 1 ps

`include "defines.v"

// select one option only
`define TEST_PROG  1
//`define TEST_JTAG  1


// testbench module
module tinyriscv_soc_tb;

    reg clk;
    reg rst_n;
    reg [1:0] gpio_t;
    wire [1:0] gpio_o;

    always #10 clk = ~clk;     // 50MHz

    wire[31:0] x3 = tinyriscv_soc_top_0.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire[31:0] x26 = tinyriscv_soc_top_0.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire[31:0] x27 = tinyriscv_soc_top_0.u_tinyriscv_core.u_gpr_reg.regs[27];

    integer r;

    initial begin
        clk = 0;
        rst_n = 1'b1;
        gpio_t = 2'b0;
        $display("test running...");
        #100
        rst_n = 1'b0;
        #100
        rst_n = 1'b1;
        #300
        gpio_t[0] = 1'b1;
        #500
        gpio_t[0] = 1'b0;
        gpio_t[1] = 1'b1;
        #100
        gpio_t[1] = 1'b0;
    end
    
    always@(posedge tinyriscv_soc_top_0.uart_0.uart_status[0])begin
        $write("%s",tinyriscv_soc_top_0.uart_0.uart_tx[7:0]);
    end

    // read mem data
    initial begin
        $readmemh ("C://Users/YiZhi_W/Desktop/tinyriscv/sim/inst.data", tinyriscv_soc_top_0.u_rom.u_gen_ram.ram);
    end

    assign gpio_o = gpio_t;
    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst_ext_i(rst_n),
        .gpio(gpio_o)
`ifdef TEST_JTAG
        ,
        .jtag_TCK(TCK),
        .jtag_TMS(TMS),
        .jtag_TDI(TDI),
        .jtag_TDO(TDO)
`endif
    );

endmodule
