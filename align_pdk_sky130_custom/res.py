import math
from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class ResGenerator(DefaultCanvas):
    """
    Sky130 polysilicon resistor generator.

    Draws a single straight poly resistor body with M1/M2 terminal straps.
    Both terminals are exposed as horizontal M2 pins using the stock M2 wire
    generator so that the router sees ordinary-width pins and no
    remove_duplicates width conflicts occur.
    """

    def __init__(self, pdk, fin, finDummy):
        super().__init__(pdk)

        # 1 nm physical grid for drawing the resistor body and V0 contacts.
        self.nm_clg = SingleGrid(pitch=1, offset=0)

        self.poly = self.addGen(Region('poly', 'Poly',
                                       h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.v0 = self.addGen(Region('v0', 'V0',
                                     h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.bbox_gen = self.addGen(Region('bbox_gen', 'Boundary',
                                           h_grid=self.nm_clg, v_grid=self.nm_clg))

    def addResArray(self, x_cells, y_cells, nfin, unit_res):
        # Only a single resistor primitive is supported for now.
        assert x_cells == 1 and y_cells == 1, "Only single resistor is supported"

        R = float(unit_res)

        # Poly geometry from the PDK abstraction (nm).
        w_poly = self.pdk['Poly']['Width']

        # Use a sky130 high-resistance poly sheet value (ohms per square).
        # This only sizes the body; real resistance is extracted by PEX.
        rsh = 300.0

        w = w_poly
        l_poly = int(round(R / rsh * w))
        l_poly = max(l_poly, w)

        # Round length up to a multiple of LCM(M1 pitch, M2 pitch) so the
        # top terminal lands on legal routing tracks.
        m1_pitch = self.pdk['M1']['Pitch']
        m2_pitch = self.pdk['M2']['Pitch']
        lcm_pitch = (m1_pitch * m2_pitch) // math.gcd(m1_pitch, m2_pitch)
        l_aligned = ((l_poly + lcm_pitch - 1) // lcm_pitch) * lcm_pitch
        l_aligned = max(l_aligned, lcm_pitch)

        logger.debug(f"Resistor R={R}  W={w}  L={l_aligned}")

        half_w = w // 2

        # Poly resistor body (centered at x=0).
        self.addRegion(self.poly, 'R_BODY',
                       -half_w, 0,
                       half_w, l_aligned)

        # Bottom and top terminals.
        self._draw_terminal('PLUS', 0)
        self._draw_terminal('MINUS', l_aligned)

        # Boundary.  Width is rounded to a multiple of the M3 pitch and height
        # to a multiple of the M2 pitch, as required by ALIGN's LEF generator.
        # The extent must fully contain the M2 pin stubs.
        m2_pitch = self.pdk['M2']['Pitch']
        m3_pitch = self.pdk['M3']['Pitch']

        pin_left = self.m2.spg.value((-3, 1))[0]
        pin_right = self.m2.spg.value((3, -1))[0]

        x_shapes = max(-pin_left, pin_right)
        x0 = -((x_shapes + m3_pitch - 1) // m3_pitch) * m3_pitch
        x1 = -x0

        y0 = -m2_pitch
        y1 = l_aligned + m2_pitch

        self.addRegion(self.bbox_gen, 'Boundary', x0, y0, x1, y1)

    def _draw_terminal(self, net, y_term):
        # V0 contact centered at (x=0, y=y_term).
        v0_wx = self.pdk['V0']['WidthX']
        v0_wy = self.pdk['V0']['WidthY']
        half_v0_x = v0_wx // 2
        half_v0_y = v0_wy // 2

        self.addRegion(self.v0, net,
                       -half_v0_x, y_term - half_v0_y,
                       half_v0_x, y_term + half_v0_y)

        m2_pitch = self.pdk['M2']['Pitch']

        # M2 horizontal routing track for this terminal.
        m2_track = y_term // m2_pitch

        # M1 vertical strap at x=0.  Two M2-pitch long so it covers the V0/V1
        # stack at y_term with enough enclosure.
        if y_term == 0:
            self.addWire(self.m1, net, 0, (-1, 1), (1, -1))
        else:
            self.addWire(self.m1, net, 0,
                         (m2_track - 1, 1), (m2_track + 1, -1))

        # V1 via connecting M1 (vertical, x=0) and M2 (horizontal, y=y_term).
        # V1 h_clg=M2, v_clg=M1, so addVia(cx,cy) maps cx->M1 and cy->M2.
        self.addVia(self.v1, net, 0, m2_track)

        # M2 horizontal pin stub.
        self.addWire(self.m2, net, m2_track, (-3, 1), (3, -1), netType='pin')
