if {![info exists PROJECT_NAME]} { 
	set PROJECT_NAME Processor 
} 
 
if {![info exists PROJECT_DIR]} { 
	set PROJECT_DIR $PROJECT_NAME 
} 
 
if {![info exists FPGA_PART]} { 
	set FPGA_PART xcku060-ffva1156-2-e 
} 
 
if {![info exists TARGET_LANG]} { 
	set TARGET_LANG VHDL 
} 
 
if {![info exists SIM_LANG]} { 
	set SIM_LANG VHDL 
} 
 
if {![info exists INCREMENTAL_BUILD]} { 
	set INCREMENTAL_BUILD false 
} 
 
if {![info exists TOP_FILE_NAME]} { 
	set TOP_FILE_NAME $PROJECT_NAME\_TOP 
} 
 
if {![info exists SIM_TOP_FILE_NAME]} { 
	set SIM_TOP_FILE_NAME $PROJECT_NAME\_TB 
} 
 
if {![info exists TCL_DIR]} { 
	set TCL_DIR tcl 
} 
 
if {![info exists SRC_DIR]} { 
	set SRC_DIR src 
} 
 
if {![info exists SIM_DIR]} { 
	set SIM_DIR tb 
} 
 
if {![info exists CNSTR_DIR]} { 
	set CNSTR_DIR cnstr 
} 
set __CNSTR_PATH "[file normalize "$CNSTR_DIR"]" 
 
if {![info exists IP_NAME]} { 
	set IP_NAME Processor 
} 
 
if {![info exists IP_PATH]} { 
	set IP_PATH ../ip 
} 
set __IP_PATH "[file normalize "$IP_PATH"]" 
 
if {![info exists DOCS_PATH]} { 
	set DOCS_PATH docs 
} 
set __DOCS_PATH "[file normalize "./$DOCS_PATH/"]" 
