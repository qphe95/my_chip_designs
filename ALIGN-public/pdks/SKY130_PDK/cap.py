from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class CapGenerator(DefaultCanvas):
    """
    Sky130 MIM capacitor generator for ``sky130_fd_pr__cap_mim_m3_1``.

    Stack (Sky130 names in parentheses):
      * bottom plate = ALIGN M4  (Sky130 met3)
      * top plate    = CapMIMLayer / capm (Sky130 capm, GDS 89/44)
      * top-plate contact = mimcc, drawn on ALIGN V4 (Sky130 via3, GDS 70/44)
      * top routing  = ALIGN M5  (Sky130 met4)

    Both terminals are brought down to horizontal M2 pins so the ALIGN router
    sees ordinary block pins.
    """

    def __init__(self, pdk):
        super().__init__(pdk)

        # 1 nm grid for the MIM dielectric, mimcc contacts, and boundary.
        self.nm_clg = SingleGrid(pitch=1, offset=0)

        self.mim_region = self.addGen(Region('mim_region', 'CapMIMLayer',
                                             h_grid=self.nm_clg, v_grid=self.nm_clg))
        # mimcc contacts are drawn on the CapMIMContact layer, which maps to
        # Sky130 via3 (GDS 70/44).  Magic treats 70/44 rectangles that overlap
        # capm as mimcc contacts between capm and met4; we keep them on a
        # separate layer so ALIGN's V4 via checks are not applied to them.
        self.mimcc = self.addGen(Region('mimcc', 'CapMIMContact',
                                        h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.bbox_gen = self.addGen(Region('bbox_gen', 'Boundary',
                                           h_grid=self.nm_clg, v_grid=self.nm_clg))

    def addCap(self, length, width):
        L = int(length)
        W = int(width)
        capm_enc = self.pdk['CapMIMLayer']['Enclosure']

        m2_pitch = self.pdk['M2']['Pitch']
        m3_pitch = self.pdk['M3']['Pitch']
        m4_pitch = self.pdk['M4']['Pitch']
        m5_pitch = self.pdk['M5']['Pitch']
        m4_width = self.pdk['M4']['Width']
        m5_width = self.pdk['M5']['Width']

        # Choose an M4 track in the middle of the capacitor.  Because m4_pitch
        # is a multiple of m2_pitch, this y-level is also on the M2 grid.
        m4_track = int(round((W / 2) / m4_pitch))
        y_level = m4_track * m4_pitch
        m2_track = y_level // m2_pitch

        # Custom M4 bottom plate: one horizontal rectangle covering the whole
        # capacitor area.  Width is W plus capm enclosure on both sides.
        m4_plate_width = W + 2 * capm_enc
        m4_plate = self.addGen(Wire('m4_plate', 'M4', 'h',
                                    clg=UncoloredCenterLineGrid(pitch=m4_plate_width,
                                                                width=m4_plate_width,
                                                                offset=y_level),
                                    spg=SingleGrid(pitch=1, offset=0)))

        # M5 top-plate routing stripe, placed over the capacitor body so the
        # mimcc contacts land inside the capm region.  It extends below the
        # bottom plate to an M4 island used to drop the PLUS pin down.
        m5_track = int(round((L / 2) / m5_pitch))
        x_m5 = m5_track * m5_pitch
        half_m5 = m5_width // 2

        # M5 route uses the standard M5 centerline grid but a simple y grid so
        # we can span from the bottom M4 island up through the capacitor.
        m5_route = self.addGen(Wire('m5_route', 'M5', 'v',
                                    clg=self.m5.clg,
                                    spg=SingleGrid(pitch=1, offset=0)))

        # M4 island for the PLUS pin drop-down, placed below the bottom plate.
        m4_island_track = -1
        y_island = m4_island_track * m4_pitch
        m4_island = self.addGen(Wire('m4_island', 'M4', 'h',
                                     clg=self.m4.clg,
                                     spg=SingleGrid(pitch=1, offset=0)))

        # ---- Capacitor body ----
        # Bottom plate (met3).
        self.addWire(m4_plate, 'MINUS', 0, 0, L)

        # MIM top plate (capm), inset from the bottom plate by capm_enc.
        self.addRegion(self.mim_region, None, capm_enc, capm_enc,
                       L - capm_enc, W - capm_enc)

        # M5 top-plate routing stripe.  Start low enough that the V4 via landing
        # on the M4 island is enclosed by M5 (DefaultCanvas already computed the
        # needed extension in self.v4.v_ext).
        self.addWire(m5_route, 'PLUS', m5_track,
                     y_island - self.v4.v_ext, W)

        # mimcc contact array under the M5 stripe, inside the capm region.
        # Magic DRC wants mimcc >= 320 nm, surrounded by capm >= 80 nm,
        # and spaced >= 80 nm.  We draw them as Regions so ALIGN does not try
        # to enforce M4/M5 via enclosure here.  They are left with no netName
        # because they are just drawn contacts, not ALIGN vias.
        mimcc_size = 360
        mimcc_space = 120
        x_mimcc_left = max(capm_enc + mimcc_space, x_m5 - half_m5 + mimcc_space)
        x_mimcc_right = min(L - capm_enc - mimcc_space, x_m5 + half_m5 - mimcc_space)
        y = capm_enc + mimcc_space
        while y + mimcc_size <= W - capm_enc - mimcc_space:
            self.addRegion(self.mimcc, None,
                           x_mimcc_left, y,
                           x_mimcc_left + mimcc_size, y + mimcc_size)
            y += mimcc_size + mimcc_space

        # ---- MINUS terminal: M4 plate -> V3 -> M3 -> V2 -> M2 pin ----
        m3_track_minus = max(1, int(round((L / 4) / m3_pitch)))
        self.addVia(self.v3, 'MINUS', m3_track_minus, m4_track)
        self.addWire(self.m3, 'MINUS', m3_track_minus,
                     (m2_track - 1, 1), (m2_track, 3))
        self.addVia(self.v2, 'MINUS', m3_track_minus, m2_track)
        self.addWire(self.m2, 'MINUS', m2_track,
                     (m3_track_minus, -1), (m3_track_minus + 2, 1),
                     netType='pin')

        # ---- PLUS terminal: M5 -> V4 -> M4 island -> V3 -> M3 -> V2 -> M2 ----
        # Bring the PLUS pin out on M2 below the capacitor where it is clear of
        # the M4 bottom plate.  The M4 island is a horizontal strap at the same
        # M4 track as the bottom of the M5 stripe; it is wide enough to land both
        # the V4 via under the M5 stripe and the V3 via that drops down to M3.
        m3_track_plus = int(round(x_m5 / m3_pitch))
        x_m3 = m3_track_plus * m3_pitch

        island_half_x = max(m4_width, m3_pitch) + abs(x_m5 - x_m3)
        self.addWire(m4_island, 'PLUS', m4_island_track,
                     min(x_m5, x_m3) - island_half_x,
                     max(x_m5, x_m3) + island_half_x)
        # V4 connects M5 (vertical) and M4 island (horizontal) at the island.
        self.addVia(self.v4, 'PLUS', m5_track, m4_island_track)
        # V3 drops from the island to the vertical M3 strap.
        self.addVia(self.v3, 'PLUS', m3_track_plus, m4_island_track)

        # M2 pin sits at the same M2 track as the island, below the cap body.
        m2_track_plus = y_island // m2_pitch
        self.addWire(self.m3, 'PLUS', m3_track_plus,
                     (m2_track_plus - 1, 1), (m2_track_plus, 3))
        self.addVia(self.v2, 'PLUS', m3_track_plus, m2_track_plus)
        self.addWire(self.m2, 'PLUS', m2_track_plus,
                     (m3_track_plus, -1), (m3_track_plus + 2, 1),
                     netType='pin')

        # ---- Boundary ----
        # Enclose the drawn shapes and snap to the M3/M2 placement grid.
        x0 = -((half_m5 + m3_pitch - 1) // m3_pitch) * m3_pitch

        m4_top = y_level + m4_plate_width // 2
        m5_bottom = y_island - self.v4.v_ext
        m5_right = x_m5 + half_m5
        island_bottom = y_island - m4_width // 2
        min_y = min(0, m5_bottom, island_bottom)
        y0 = -((-min_y + m2_pitch - 1) // m2_pitch) * m2_pitch

        def m2_pin_right(track):
            return self.m2.spg.value((track + 2, 1))[0]

        x_shapes = max(L, m5_right,
                       m2_pin_right(m3_track_minus),
                       m2_pin_right(m3_track_plus))
        y_shapes = max(W, m4_top, y_level + m4_pitch)

        x1 = x0 + ((x_shapes - x0 + m3_pitch - 1) // m3_pitch) * m3_pitch
        y1 = y0 + ((y_shapes - y0 + m2_pitch - 1) // m2_pitch) * m2_pitch

        self.addRegion(self.bbox_gen, 'Boundary', x0, y0, x1, y1)
