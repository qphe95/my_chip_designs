import math
import os
from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class ResGenerator(DefaultCanvas):
    """
    Sky130 polysilicon resistor generator with serpentine folding.

    Instead of drawing the resistor as one absurdly long straight poly strip,
    the body is folded into multiple vertical segments connected by poly
    U-turns.  This produces a compact, near-rectangular primitive that can be
    packed next to a capacitor instead of being stacked on top of it.

    The PLUS and MINUS terminals are exposed as ordinary-width horizontal M2
    pins using the stock M2 wire generator, so the router sees legal pins and
    no remove_duplicates width conflicts occur.
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
        pitch_poly = self.pdk['Poly']['Pitch']

        # Use a Sky130 high-resistance poly sheet value (ohms per square).
        # This only sizes the body; real resistance is extracted by PEX.
        rsh = 300.0

        # Ideal straight length for the requested resistance.
        l_ideal = R / rsh * w_poly

        # Choose how many vertical segments (folds) to use.  A smaller ceiling
        # makes the resistor shorter and wider.  The default can be overridden
        # via the environment for experimentation.
        max_seg_nm = int(os.environ.get('ALIGN_RES_MAX_SEGMENT_NM', 12000))
        n_seg = max(1, math.ceil(l_ideal / max_seg_nm))

        # Prefer an even number of segments so both terminals end up on the
        # same side (bottom) of the serpentine.  This makes it easy to align
        # the resistor with a capacitor placed to its right.
        if n_seg % 2 != 0:
            n_seg += 1

        # Each U-turn adds ``pitch_poly`` of horizontal poly.  Back that out
        # of the total length before dividing among the vertical segments.
        turn_len = pitch_poly
        l_seg = int(round((l_ideal - (n_seg - 1) * turn_len) / n_seg))
        l_seg = max(l_seg, w_poly)

        # Physical x positions of the vertical poly segments.
        x_centers = [i * pitch_poly for i in range(n_seg)]
        half_w = w_poly // 2

        logger.debug(
            f"Resistor R={R} n_seg={n_seg} seg_len={l_seg} "
            f"width={(n_seg - 1) * pitch_poly + w_poly}"
        )

        # Draw the vertical poly segments.
        for i, x in enumerate(x_centers):
            # Even segments run bottom-to-top, odd segments top-to-bottom.
            # The layer is the same; only the order of the endpoints matters
            # for connectivity visualization.
            self.addRegion(self.poly, 'R_BODY',
                           x - half_w, 0,
                           x + half_w, l_seg)

        # Draw the poly U-turns between adjacent segments.
        for i in range(n_seg - 1):
            x0 = x_centers[i] + half_w
            x1 = x_centers[i + 1] - half_w
            if i % 2 == 0:
                y_turn = l_seg
            else:
                y_turn = 0
            self.addRegion(self.poly, 'R_BODY',
                           x0, y_turn - half_w,
                           x1, y_turn + half_w)

        # Terminals: PLUS at the start (bottom-left), MINUS at the end
        # (bottom-right when n_seg is even).
        self._draw_terminal('PLUS', x_centers[0], 0)
        self._draw_terminal('MINUS', x_centers[-1], 0)

        # Boundary.  Width is rounded to a multiple of the M3 pitch and height
        # to a multiple of the M2 pitch, as required by ALIGN's LEF generator.
        m2_pitch = self.pdk['M2']['Pitch']
        m3_pitch = self.pdk['M3']['Pitch']

        # The M2 pin for terminal i is centered at x_centers[i] and extends
        # from (i-3,1) to (i+3,-1) on the M2 stop-point grid.  Compute its
        # half-width in physical units once from the i=0 case.
        pin_left = self.m2.spg.value((-3, 1))[0]
        pin_right = self.m2.spg.value((3, -1))[0]
        pin_hw = max(-pin_left, pin_right)

        left_edge = x_centers[0] - pin_hw
        right_edge = x_centers[-1] + pin_hw

        x0 = -((-left_edge + m3_pitch - 1) // m3_pitch) * m3_pitch
        x1 = ((right_edge + m3_pitch - 1) // m3_pitch) * m3_pitch

        y0 = -m2_pitch
        # Round total cell height up to a multiple of the M2 pitch, as required
        # by ALIGN's LEF generator. Total height = y1 - y0 = y1 + m2_pitch.
        total_height = l_seg + 2 * m2_pitch
        rounded_height = ((total_height + m2_pitch - 1) // m2_pitch) * m2_pitch
        y1 = rounded_height - m2_pitch

        self.addRegion(self.bbox_gen, 'Boundary', x0, y0, x1, y1)

    def _draw_terminal(self, net, x_term, y_term):
        # x_term is on the Poly/M1 pitch grid (multiples of 430 nm).  Map it
        # to the M1/M2 center-line track index.
        m1_pitch = self.pdk['M1']['Pitch']
        m2_pitch = self.pdk['M2']['Pitch']
        x_track = x_term // m1_pitch

        # V0 contact centered at (x_term, y_term).
        v0_wx = self.pdk['V0']['WidthX']
        v0_wy = self.pdk['V0']['WidthY']
        half_v0_x = v0_wx // 2
        half_v0_y = v0_wy // 2

        self.addRegion(self.v0, net,
                       x_term - half_v0_x, y_term - half_v0_y,
                       x_term + half_v0_x, y_term + half_v0_y)

        # M2 horizontal routing track for this terminal.
        m2_track = y_term // m2_pitch

        # M1 vertical strap at x=x_term.  Two M2-pitch long so it covers the
        # V0/V1 stack at y_term with enough enclosure.
        if y_term == 0:
            self.addWire(self.m1, net, x_track, (-1, 1), (1, -1))
        else:
            self.addWire(self.m1, net, x_track,
                         (m2_track - 1, 1), (m2_track + 1, -1))

        # V1 via connecting M1 (vertical, x=x_track) and M2 (horizontal,
        # y=m2_track).  V1 h_clg=M2, v_clg=M1, so addVia(cx,cy) maps cx->M1
        # and cy->M2.
        self.addVia(self.v1, net, x_track, m2_track)

        # M2 horizontal pin stub centered at x_term.
        self.addWire(self.m2, net, m2_track,
                     (x_track - 3, 1), (x_track + 3, -1), netType='pin')
