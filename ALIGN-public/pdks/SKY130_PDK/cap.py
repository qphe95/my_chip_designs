import math
from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class CapGenerator(DefaultCanvas):
    """
    Sky130 MIM capacitor generator (CAP2M style).

    The bottom plate is drawn on M4, the top plate on M5, and a CapMIMLayer
    dielectric separates them.  Both terminals are brought down to horizontal
    M2 pins through a V4->M4 tab->V3->M3->V2 tower so that the router sees
    ordinary M2 block pins.

    All coordinates are kept on the ALIGN primitive grid; the boundary is
    sized to multiples of the M3 (width) and M2 (height) routing pitches.
    """

    def __init__(self, pdk):
        super().__init__(pdk)

        # 1 nm grid for the MIM dielectric and cell boundary.
        self.nm_clg = SingleGrid(pitch=1, offset=0)

        self.mim_region = self.addGen(Region('mim_region', 'CapMIMLayer',
                                             h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.bbox_gen = self.addGen(Region('bbox_gen', 'Boundary',
                                           h_grid=self.nm_clg, v_grid=self.nm_clg))

    def addCap(self, length, width):
        L = int(length)
        W = int(width)
        enc = self.pdk['CapMIMLayer']['Enclosure']

        logger.debug(f"Capacitor L={L}  W={W}")

        m2_pitch = self.pdk['M2']['Pitch']
        m3_pitch = self.pdk['M3']['Pitch']
        m4_pitch = self.pdk['M4']['Pitch']
        m5_pitch = self.pdk['M5']['Pitch']

        half_m4 = m4_pitch // 2
        half_m5 = m5_pitch // 2

        # Choose an M4/M5 track roughly in the middle of the capacitor.  Because
        # m4_pitch is a multiple of m2_pitch, this y-level is also on the M2
        # routing grid.
        m4_track = int(round((W / 2) / m4_pitch))
        y_level = m4_track * m4_pitch
        m2_track = y_level // m2_pitch

        # Choose the M5 track for the PLUS via tower so it sits completely to
        # the right of the M4 bottom plate.
        m5_track_plus = (L + half_m5 + m5_pitch - 1) // m5_pitch
        x_plus = m5_track_plus * m5_pitch
        m3_track_plus = int(round(x_plus / m3_pitch))

        # Custom M4 wire: a single horizontal rectangle covering the entire
        # capacitor area.  Drawing it as one Wire prevents remove_duplicates
        # from treating abutting stripes as separate islands.
        m4_plate_width = W + m4_pitch
        m4_plate = self.addGen(Wire('m4_plate', 'M4', 'h',
                                    clg=UncoloredCenterLineGrid(pitch=m4_plate_width,
                                                                width=m4_plate_width,
                                                                offset=y_level),
                                    spg=SingleGrid(pitch=1, offset=0)))

        # Custom M5 wire: a single vertical rectangle covering the capacitor
        # width plus the via-tower M5 stripe.  It is centered on the M5 track
        # used by V4 so the via lands on the wire centerline.
        m5_plate_half = x_plus
        m5_plate_width = 2 * m5_plate_half
        m5_x_min = 0
        m5_x_max = m5_plate_width
        m5_plate = self.addGen(Wire('m5_plate', 'M5', 'v',
                                    clg=UncoloredCenterLineGrid(pitch=m5_plate_width,
                                                                width=m5_plate_width,
                                                                offset=x_plus),
                                    spg=SingleGrid(pitch=1, offset=0)))

        # Bottom plate.
        self.addWire(m4_plate, 'MINUS', 0, 0, L)

        # MIM dielectric.
        self.addRegion(self.mim_region, None, enc, enc, L - enc, W - enc)

        # Top plate.
        self.addWire(m5_plate, 'PLUS', 0, 0, W)

        # ---- MINUS terminal: M4 plate -> V3 -> M3 -> V2 -> M2 pin ----
        m3_track_minus = int(round((L / 4) / m3_pitch))
        # V3 connects M3 (vertical) and M4 (horizontal): cx=M3 track, cy=M4 track.
        self.addVia(self.v3, 'MINUS', m3_track_minus, m4_track)
        # M3 vertical strap covering both V2 and V3 at y_level.  Extend one
        # track below y_level so the V3 enclosure rule is satisfied.
        self.addWire(self.m3, 'MINUS', m3_track_minus,
                     (m2_track - 1, 1), (m2_track, 3))
        # V2 connects M2 (horizontal) and M3 (vertical).  For V2,
        # h_clg=M2, v_clg=M3, so addVia(cx,cy) maps cx->M3 and cy->M2.
        self.addVia(self.v2, 'MINUS', m3_track_minus, m2_track)
        # M2 horizontal pin stub.  Extend one stoppoint past the via center so
        # the via landing is fully covered by the pin rectangle.
        self.addWire(self.m2, 'MINUS', m2_track,
                     (m3_track_minus, -1), (m3_track_minus + 2, 1),
                     netType='pin')

        # ---- PLUS terminal: M5 plate -> V4 -> M4 tab -> V3 -> M3 -> V2 -> M2 pin ----
        # M4 PLUS tab (horizontal) landing for V4.  It is centered on the M5
        # stripe and separated from the MINUS plate by at least half an M5 pitch.
        tab_left = x_plus - half_m5
        tab_right = x_plus + half_m5
        self.addWire(m4_plate, 'PLUS', 0, tab_left, tab_right)

        # V4 connects M4 (horizontal) and M5 (vertical): cx=M5 track, cy=M4 track.
        self.addVia(self.v4, 'PLUS', m5_track_plus, m4_track)
        # V3 from the M4 tab down to M3.
        self.addVia(self.v3, 'PLUS', m3_track_plus, m4_track)
        # M3 vertical strap covering both V2 and V3 at y_level.
        self.addWire(self.m3, 'PLUS', m3_track_plus,
                     (m2_track - 1, 1), (m2_track, 3))
        # V2 to M2.
        self.addVia(self.v2, 'PLUS', m3_track_plus, m2_track)
        # M2 horizontal pin stub.
        self.addWire(self.m2, 'PLUS', m2_track,
                     (m3_track_plus, -1), (m3_track_plus + 2, 1),
                     netType='pin')

        # ---- Boundary ----
        # Lower-left origin is chosen so the M5 plate left edge and the M4 plate
        # bottom edge are enclosed.  It is also snapped to the M3/M2 grids so
        # that internal vertical straps and M2 pin centers stay on the router
        # grids after the cell is placed at an integer boundary.
        x0 = -((half_m5 + m3_pitch - 1) // m3_pitch) * m3_pitch
        y0 = -((half_m4 + m2_pitch - 1) // m2_pitch) * m2_pitch

        # Right/top edges of the drawn shapes.
        m4_top = y_level + (W + m4_pitch) // 2
        m5_right = m5_x_max
        m4_tab_right = tab_right

        # M2 pin right edges (M2 stoppoint grid aligned to M3, (track+2, 1)).
        def m2_pin_right(track):
            return self.m2.spg.value((track + 2, 1))[0]

        x_shapes = max(m5_right,
                       m4_tab_right,
                       m2_pin_right(m3_track_minus),
                       m2_pin_right(m3_track_plus))
        y_shapes = max(W, m4_top, y_level + m4_pitch)

        # Round up to the nearest legal LEF grid from the origin.
        x1 = x0 + ((x_shapes - x0 + m3_pitch - 1) // m3_pitch) * m3_pitch
        y1 = y0 + ((y_shapes - y0 + m2_pitch - 1) // m2_pitch) * m2_pitch

        self.addRegion(self.bbox_gen, 'Boundary', x0, y0, x1, y1)
