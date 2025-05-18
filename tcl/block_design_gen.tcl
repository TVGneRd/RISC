update_compile_order -fileset sources_1
create_bd_design "design_1"

create_bd_cell -type ip -vlnv SUAI:STUDENT:Processor:1.0 Processor_0
create_bd_cell -type ip -vlnv SUAI:STUDENT:ProgramMemory:1.0 ProgramMemory_0
connect_bd_intf_net [get_bd_intf_pins ProgramMemory_0/S_AXI] [get_bd_intf_pins Processor_0/M_AXI]

make_bd_pins_external  [get_bd_pins Processor_0/refclk]
make_bd_pins_external  [get_bd_pins Processor_0/rst]

connect_bd_net [get_bd_ports refclk_0] [get_bd_pins ProgramMemory_0/refclk]
connect_bd_net [get_bd_ports rst_0] [get_bd_pins ProgramMemory_0/rst]

set_property name refclk [get_bd_ports refclk_0]
set_property name rst [get_bd_ports rst_0]

make_wrapper -files [get_files $CURRENT_DIR/$PROJECT_NAME/$PROJECT_NAME.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse $CURRENT_DIR/$PROJECT_NAME/$PROJECT_NAME.gen/sources_1/bd/design_1/hdl/design_1_wrapper.vhd
set_property library work [get_files $CURRENT_DIR/$PROJECT_NAME/$PROJECT_NAME.gen/sources_1/bd/design_1/hdl/design_1_wrapper.vhd]
update_compile_order -fileset sources_1

set_property top RISC_TB [get_filesets sim_1]
regenerate_bd_layout