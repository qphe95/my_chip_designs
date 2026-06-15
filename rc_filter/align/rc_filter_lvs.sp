* LVS reference netlist for RC_FILTER
* Uses the Sky130 device models that Magic extracts from the layout.

.subckt rc_filter vin vout vss
R0 vin vout sky130_fd_pr__res_generic_po w=30 l=10046
X0 vout vss sky130_fd_pr__cap_mim_m3_1 l=1940 w=1940
.ends
