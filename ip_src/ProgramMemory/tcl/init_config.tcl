set PROJECT_NAME ProgramMemory
set PROJECT_DIR ProgramMemory
set INCREMENTAL_BUILD false
set FPGA_PART xc7v585tffg1157-2
set TARGET_LANG VHDL
set SIM_LANG VHDL
set SRC_DIR src
set TCL_DIR tcl
set SIM_DIR tb
set CNSTR_DIR cnstr
set SIM_TOP_FILE_NAME ProgramMemory_TB
set TOP_FILE_NAME ProgramMemory_TOP
start_gui
source   -notrace  tcl/make_prj.tcl
