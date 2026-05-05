onerror {resume}
quietly virtual signal -install /testbench/dut/accel { (context /testbench/dut/accel )&{FE_PHN1838_iomem_accel_1__7 , FE_PHN1837_iomem_accel_1__6 , FE_PHN1850_iomem_accel_1__5 , FE_PHN1833_iomem_accel_1__4 , FE_PHN1300_iomem_accel_1__3 , FE_PHN1802_iomem_accel_1__2 , FE_PHN1815_iomem_accel_1__1 , FE_PHN1821_iomem_accel_1__0 }} Start_node
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/dut/accel/iomem_accel_0__0_
add wave -noupdate -radix decimal /testbench/dut/accel/Start_node
add wave -noupdate /testbench/dut/accel/iomem_accel_0__1_
add wave -noupdate /testbench/dut/accel/iomem_accel_0__2_
add wave -noupdate /testbench/dut/accel/finished_accel
add wave -noupdate -radix decimal /testbench/accel_o_path_node
add wave -noupdate /testbench/accel_o_path_node_valid
add wave -noupdate /testbench/dut/clk
add wave -noupdate /testbench/dut/accel/FE_PHN1712_iomem_accel_0__0
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {18723302 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 281
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {15504285 ns} {21115137 ns}
