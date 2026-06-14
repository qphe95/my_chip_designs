* RC Low-Pass Filter for ALIGN automatic layout generation
* Target: SkyWater 130 nm (sky130A)
* R1 = 100 kOhm.  C1 is a scaled-down MIM cap (10u x 10u) so the
* ALIGN-generated layout is compact and the resistor/capacitor are
* visible at similar scale.

.subckt rc_filter vin vout vss
R1 vin n1 resistor r=100k
C1 n1 vss sky130_fd_pr__cap_mim_m3_1 w=10u l=10u
.ends rc_filter
