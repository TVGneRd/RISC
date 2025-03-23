#setting env 
set script_path [ file dirname [ file normalize [ info script ] ] ] 
cd $script_path 
cd ../ 
set CURRENT_DIR [pwd] 
 
puts "script dir: $script_path"  
puts "work dir: $CURRENT_DIR"  
#end setting env 
 
source $script_path/default_values.tcl 
 
puts "project name: $PROJECT_NAME"  
puts "FPGA part: $FPGA_PART"  
puts "target lang: $TARGET_LANG" 
 
close_project -quiet 
if { [file exists $PROJECT_DIR] != 0 } {  
	file delete -force $PROJECT_NAME 
	puts "Delete old Project" 
} 

set_param gui.addressMap 0

create_project $PROJECT_NAME $PROJECT_DIR -part $FPGA_PART 
set_property target_language $TARGET_LANG [current_project] 
set_property simulator_language $SIM_LANG [current_project] 
set_property  ip_repo_paths  $__IP_PATH [current_project] 
 
update_ip_catalog 
 
add_files -fileset constrs_1 -quiet  [glob -nocomplain $CNSTR_DIR/*] 
add_files -fileset sources_1  [glob  $SRC_DIR/*]  
add_files -fileset sim_1 [glob  $SIM_DIR/*]  
set SRC_DIR_PATH "[file normalize "$SRC_DIR"]" 
set SIM_DIR_PATH "[file normalize "$SIM_DIR"]" 
set_property library work [get_files  $SRC_DIR_PATH/*]
set_property library work [get_files  $SIM_DIR_PATH/*]
 
update_ip_catalog 
 
update_compile_order -quiet  -fileset sources_1 
 
set_property -quiet  top $TOP_FILE_NAME [get_filesets sources_1] 
 
set_property INCREMENTAL $INCREMENTAL_BUILD [get_filesets sim_1] 
 
update_compile_order -quiet -fileset sources_1 
update_compile_order -quiet -fileset sim_1 
set_property -name {xsim.simulate.runtime} -value {} -objects [get_filesets sim_1]
