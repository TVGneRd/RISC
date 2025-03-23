#CONFIG
PROJECT_NAME ?= Processor
PROJECT_DIR ?= $(PROJECT_NAME)
FPGA_PART ?= xc7v585tffg1157-2
VIVADO_VERSION ?= 2022.2
TARGET_LANG ?= VHDL
SIM_LANG ?= VHDL
INCREMENTAL_BUILD ?= false
#CONFIG END

DEBUG_TCL ?= 

LOG_DIR ?= logs
TEMP_DIR ?= temp
TCL_DIR ?= tcl
SRC_DIR ?= src
SIM_DIR ?= tb
CNSTR_DIR ?= cnstr

TCL_PRJ_MAKE_NAME ?= make_prj
TCL_CONFIG_NAME ?= init_config
JOURNAL_NAME ?= vivado_journal
LOG_NAME ?= vivado_runlog
TOP_FILE_NAME ?= $(PROJECT_NAME)_TOP
SIM_TOP_FILE_NAME ?= $(PROJECT_NAME)_TB

JOURNAL_PATH ?= $(LOG_DIR)/$(JOURNAL_NAME).jou
LOG_PATH ?= $(LOG_DIR)/$(LOG_NAME).log
TCL_CONFIG ?= $(TCL_DIR)/$(TCL_CONFIG_NAME).tcl
TCL_INIT_PRJ ?=  $(TCL_DIR)/$(TCL_PRJ_MAKE_NAME).tcl
TCL_PACKER ?= $(TCL_DIR)/$(TOP_FILE_NAME)_packer.tcl
PRJ_XPR ?= $(PROJECT_DIR)/$(PROJECT_NAME).xpr

UNAME := $(shell uname -m)
TRACE := $(if $(DEBUG_TCL),   ,  -notrace)

ENV ?= /tools/Xilinx/Vivado/$(VIVADO_VERSION)/settings64.sh

all:

conf:
	@echo "set PROJECT_NAME $(PROJECT_NAME)" > $(TCL_CONFIG)
	@echo "set PROJECT_DIR $(PROJECT_DIR)" >> $(TCL_CONFIG)
	@echo "set INCREMENTAL_BUILD $(INCREMENTAL_BUILD)" >> $(TCL_CONFIG)
	@echo "set FPGA_PART $(FPGA_PART)" >> $(TCL_CONFIG)
	@echo "set TARGET_LANG $(TARGET_LANG)" >> $(TCL_CONFIG)
	@echo "set SIM_LANG $(SIM_LANG)" >> $(TCL_CONFIG)
	@echo "set SRC_DIR $(SRC_DIR)" >> $(TCL_CONFIG)
	@echo "set TCL_DIR $(TCL_DIR)" >> $(TCL_CONFIG)
	@echo "set SIM_DIR $(SIM_DIR)" >> $(TCL_CONFIG)
	@echo "set CNSTR_DIR $(CNSTR_DIR)" >> $(TCL_CONFIG)
	@echo "set SIM_TOP_FILE_NAME $(SIM_TOP_FILE_NAME)" >> $(TCL_CONFIG)
	@echo "set TOP_FILE_NAME $(TOP_FILE_NAME)" >> $(TCL_CONFIG)

init_prj:
	@echo "source $(TRACE)  $(TCL_INIT_PRJ)" >> $(TCL_CONFIG)

conf_gui : conf
	@echo "start_gui" >> $(TCL_CONFIG)

open_prj:
	@echo "open_project $(PRJ_XPR)" >> $(TCL_CONFIG)

start_vivado_shell: conf init_prj
	@bash  $(ENV)

start: conf
	@echo "vivado ver: $(VIVADO_VERSION)"
	@vivado -tempDir $(TEMP_DIR) -journal $(JOURNAL_PATH) -log $(LOG_PATH) -mode tcl $(TRACE)  -source $(TCL_CONFIG)

shell_build: conf
	@echo "exit" >> $(TCL_CONFIG)

prj: shell_build  start

zip: clean-all
	@zip $(PROJECT_NAME).zip -r ./

nogui: conf init_prj start

shell: start_vivado_shell

gui: conf_gui init_prj start

reopen_vivado: conf_gui open_prj start

all: gui

clean:
	@$(RM) -r $(TEMP_DIR)
	@$(RM) -r $(PROJECT_DIR)
	@$(RM) -r VIVADO_PROJECT

clean-all: 
	@$(RM) -r $(LOG_DIR)/*
	@$(RM) *pid*
	@$(RM) *.tmp
	@$(RM) *.Xil
	@$(RM) *.log
	@$(RM) *.jou
	@$(RM) *.zip
	@$(RM) $(TCL_CONFIG)
