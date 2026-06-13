#!/usr/bin/env python3
"""
Plot ngspice transient simulation output.
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

data = np.loadtxt("tran_out")
t = data[:, 0]
vin = data[:, 1]
vout = data[:, 3]

# Full transient view
fig, axes = plt.subplots(2, 1, figsize=(10, 8))

axes[0].plot(t * 1e3, vin, label="Vin (input)", linewidth=1.5)
axes[0].plot(t * 1e3, vout, label="Vout (filtered)", linewidth=1.5)
axes[0].set_xlabel("Time (ms)")
axes[0].set_ylabel("Voltage (V)")
axes[0].set_title("RC Low-Pass Filter - Full Transient")
axes[0].legend()
axes[0].grid(True)
axes[0].set_xlim(0, 5)

# Zoomed view of the first rising edge to show RC charging
axes[1].plot(t * 1e6, vin, label="Vin (input)", linewidth=1.5)
axes[1].plot(t * 1e6, vout, label="Vout (filtered)", linewidth=1.5)
axes[1].set_xlabel("Time (µs)")
axes[1].set_ylabel("Voltage (V)")
axes[1].set_title("Zoomed First Rising Edge (τ = R·C = 1 µs)")
axes[1].legend()
axes[1].grid(True)
axes[1].set_xlim(0, 10)
axes[1].axhline(y=0.632, color="r", linestyle="--", alpha=0.5, label="63.2%")

plt.tight_layout()
plt.savefig("rc_filter_plot.png", dpi=150)
print("Saved plot to rc_filter_plot.png")
