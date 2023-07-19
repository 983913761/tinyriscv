RISCV_ARCH := rv32im
RISCV_ABI := ilp32
RISCV_MCMODEL := medlow

TARGET := coremark

C_SRCS := \
	core_list_join.c \
	core_main.c \
	core_matrix.c \
	core_state.c \
	core_util.c \
	core_portme.c \

CFLAGS += -DSIMULATION

COMMON_DIR = ..
TOOLCHAIN_DIR = ../../..
include ../common.mk
