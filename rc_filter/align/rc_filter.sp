* RC Low-Pass Filter for ALIGN automatic layout generation
* Target: SkyWater 130 nm (sky130A)
* R1 = 100 kOhm, C1 = 10 pF
* fc = 1 / (2*pi*R*C) ~ 159 kHz

.subckt rc_filter vin vout vss
R1 vin n1 resistor r=100k
C1 n1 vss sky130_fd_pr__cap_mim_m3_1 w=70u l=70u
.ends rc_filter
