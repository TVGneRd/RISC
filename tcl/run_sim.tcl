#close_sim

if { [current_sim] != "" } {
    relaunch_sim
    run all
} else {
    set sim_fileset sim_1
    launch_simulation -simset [get_filesets $sim_fileset]
    add_condition -notrace test_completed {
        stop
        puts "Test: OK"
    }
    run all
}
