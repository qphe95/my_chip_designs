from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class ResGenerator(DefaultCanvas):
    """
    Sky130 polysilicon resistor generator.

    Draws a single straight poly resistor body with M1/M2 terminal straps.
    The poly body is covered with the Sky130 poly-resistor marker layer so
    Magic extracts it as a ``sky130_fd_pr__res_generic_po`` device during PEX.
    """

    def __init__(self, pdk, fin, finDummy):
        super().__init__(pdk)

        # 1 nm physical grid for drawing the resistor body and V0 contacts.
        self.nm_clg = SingleGrid(pitch=1, offset=0)

        self.poly = self.addGen(Region('poly', 'Poly',
                                       h_grid=self.nm_clg, v_grid=self.nm_clg))
        # Sky130 resistor marker layer (GDS 66/13) so Magic recognizes the poly
        # as a resistor device.
        self.poly_res = self.addGen(Region('poly_res', 'PolyRes',
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

        # Use a Sky130 high-resistance poly sheet value (ohms per square).
        # This only sizes the body; real resistance is extracted by PEX.
        rsh = 300.0

        # Minimum width is the drawn poly width.
        w = w_poly
        # Length required for the target resistance.
        l_poly = int(round(R / rsh * w))
        l_poly = max(l_poly, w)

        # Round length up to a multiple of the M2 pitch so the top M2 pin is
        # on the placement grid.  M1 pins are allowed to be off-grid.
        m1_pitch = self.pdk['M1']['Pitch']
        m2_pitch = self.pdk['M2']['Pitch']
        l_aligned = ((l_poly + m2_pitch - 1) // m2_pitch) * m2_pitch
        l_aligned = max(l_aligned, m2_pitch)

        logger.debug(f"Resistor R={R}  W={w}  L={l_aligned}")

        half_w = w // 2

        # Poly resistor body (centered at x=0).
        self.addRegion(self.poly, 'R_BODY',
                       -half_w, 0,
                       half_w, l_aligned)

        # Cover the poly body with the Sky130 resistor marker layer so Magic
        # extracts it as sky130_fd_pr__res_generic_po.
        self.addRegion(self.poly_res, 'R_BODY',
                       -half_w, 0,
                       half_w, l_aligned)

        # Bottom terminal.
        self._draw_terminal('PLUS', 0)
        # Top terminal.
        self._draw_terminal('MINUS', l_aligned)

        # Boundary with enough margin for pins and DRC enclosures.
        # The lower-left corner must sit on the M1/M2 placement grid so that
        # ALIGN's positive-coordinate shift keeps the pins on-grid.
        min_margin = max(w, self.pdk['M2']['Width']) * 4
        x_margin = ((min_margin + m1_pitch - 1) // m1_pitch) * m1_pitch
        y_margin = ((min_margin + m2_pitch - 1) // m2_pitch) * m2_pitch
        x0, y0 = -x_margin, -y_margin
        x1, y1 = x_margin, l_aligned + y_margin
        self.addRegion(self.bbox_gen, 'Boundary', x0, y0, x1, y1)

    def _draw_terminal(self, net, y_term):
        # V0 contact size (nm).
        v0_wx = self.pdk['V0']['WidthX']
        v0_wy = self.pdk['V0']['WidthY']
        half_v0_x = v0_wx // 2
        half_v0_y = v0_wy // 2

        # V0 contact centered at (x=0, y=y_term).
        self.addRegion(self.v0, net,
                       -half_v0_x, y_term - half_v0_y,
                       half_v0_x, y_term + half_v0_y)

        m2_pitch = self.pdk['M2']['Pitch']

        # Routing track indices for the terminal.
        m2_track = y_term // m2_pitch

        # M1 vertical strap at x=0 (M1 track 0).  It must extend far enough
        # in y to satisfy the V0 enclosure rule (VencA_L=80 for M1-V0).
        # Using the M2-aligned stop-point grid gives a 670 nm tall strap
        # centered at y_term, which comfortably encloses the 170 nm V0.
        self.addWire(self.m1, net, 0, (m2_track - 1, 1), (m2_track, 3))

        # V1 via connecting M1 (vertical, x=0) and M2 (horizontal, y=y_term).
        # addVia(cx, cy): cx is the M1 track (x), cy is the M2 track (y).
        self.addVia(self.v1, net, 0, m2_track)

        # M2 horizontal pin stub at y=y_term (M2 track).
        self.addWire(self.m2, net, m2_track,
                     (-1, 1), (1, -1), netType='pin')
