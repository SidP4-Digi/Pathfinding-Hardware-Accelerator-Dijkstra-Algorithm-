# Create a vcd directory if it doesn't exist
if {![file exists vcd]} {
    file mkdir vcd
}

# Update this value with the accelerator start time


view wave 
add wave /testbench/dut/resetn
do /home/nfs/spatil1/project/sim_phys/wave.do

run 18.272102ms



#add wave /testbench/dut/accel/iomem_accel_0__0_ /testbench/dut/accel/iomem_accel_0__1_ /testbench/dut/accel/iomem_accel_0__2_ /testbench/dut/accel/finished_accel /testbench/accel_o_path_node /testbench####/accel_o_path_node_valid /testbench/dut/clk 

#add wave /testbench/dut/accel/FE_PHN1838_iomem_accel_1__7
#add wave /testbench/dut/accel/FE_PHN1837_iomem_accel_1__6
#add wave /testbench/dut/accel/FE_PHN1850_iomem_accel_1__5
#add wave /testbench/dut/accel/FE_PHN1833_iomem_accel_1__4
#add wave /testbench/dut/accel/FE_PHN1300_iomem_accel_1__3
#add wave /testbench/dut/accel/FE_PHN1802_iomem_accel_1__2
#add wave /testbench/dut/accel/FE_PHN1815_iomem_accel_1__1
#add wave /testbench/dut/accel/FE_PHN1821_iomem_accel_1__0

#add wave /testbench/dut/accel/FE_PHN1712_iomem_accel_0__0

# Start activity annotation
set vcd_file "./vcd/et4351.phys.setup.vcd"
vcd files $vcd_file
vcd add -r -internal -ports -file $vcd_file /*
vcd dumpportson $vcd_file
vcd on $vcd_file

# Update this value with the accelerator runtime
run  3.34716ms

# Stop activity annotation
vcd off $vcd_file
vcd dumpportsoff $vcd_file


run -all

exit