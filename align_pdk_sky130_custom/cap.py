import math
from align.primitive.default.canvas import DefaultCanvas
from align.cell_fabric.generators import *
from align.cell_fabric.grid import *

import logging
logger = logging.getLogger(__name__)


class CapGenerator(DefaultCanvas):
    """
    Sky130 MIM capacitor generator (CAP2M style).

    Draws a rectangular M4 bottom plate, a CapMIMLayer dielectric, and an
    M5 top plate.  The bottom plate is exposed as a horizontal M4 pin and
    the top plate as a vertical M5 pin, both aligned to the ALIGN router
    grid so the top-level router can connect to them.
    """

    def __init__(self, pdk):
        super().__init__(pdk)

        # 1 nm physical grid for the capacitor plates and boundary
        self.nm_clg = SingleGrid(pitch=1, offset=0)

        self.m4_region = self.addGen(Region('m4_region', 'M4',
                                            h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.mim_region = self.addGen(Region('mim_region', 'CapMIMLayer',
                                             h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.m5_region = self.addGen(Region('m5_region', 'M5',
                                            h_grid=self.nm_clg, v_grid=self.nm_clg))
        self.bbox_gen = self.addGen(Region('bbox_gen', 'Boundary',
                                           h_grid=self.nm_clg, v_grid=self.nm_clg))

    def addCap(self, length, width):
        L = int(length)
        W = int(width)

        enc = self.pdk['CapMIMLayer']['Enclosure']

        logger.debug(f"Capacitor L={L}  W={W}")

        # Bottom plate (M4)
        self.addRegion(self.m4_region, 'MINUS', 0, 0, L, W)

        # MIM dielectric
        self.addRegion(self.mim_region, None,
                       enc, enc, L - enc, W - enc)

        # Top plate (M5) sits on the dielectric
        self.addRegion(self.m5_region, 'PLUS',
                       enc, enc, L - enc, W - enc)

        # M4 horizontal pin stub (MINUS) on a legal M4 track near the middle.
        # Keep the stub in the positive-x quadrant so the boundary can start
        # at (0,0) and the pin stays on the M4 grid after coordinate shifting.
        m4_pitch = self.pdk['M4']['Pitch']
        m4_track = int(round((W / 2) / m4_pitch))
        self.addWire(self.m4, 'MINUS', m4_track,
                     (0, -1), (1, 1),
                     netType='pin')

        # M5 vertical pin stub (PLUS) on a legal M5 track near the middle,
        # extending from inside the top plate to outside the capacitor.
        m5_pitch = self.pdk['M5']['Pitch']
        m5_track = int(round((L / 2) / m5_pitch))

        # M5 spg is aligned to M4 pitch.  Choose y indices so the stub starts
        # inside the M5 plate and ends outside the capacitor body.
        m4_pitch_for_m5_spg = self.pdk['M4']['Pitch']
        q = (W - enc - m4_pitch_for_m5_spg) // m4_pitch_for_m5_spg
        q = max(q, 0)
        self.addWire(self.m5, 'PLUS', m5_track,
                     (q, 1), (q + 1, -1),
                     netType='pin')

        # Boundary starting at (0,0).  The cap body and pin stubs are drawn
        # in the first quadrant so coordinate shifting does not move the pins
        # off their routing grids.  Width is rounded to a multiple of M1 pitch
        # and height to a multiple of M2 pitch for LEF.
        m1_pitch = self.pdk['M1']['Pitch']
        m2_pitch = self.pdk['M2']['Pitch']
        m5_w = self.pdk['M5']['Width']
        x1 = max(L, 590, m5_track * m5_pitch + m5_w // 2)
        x1 = ((x1 + m1_pitch - 1) // m1_pitch) * m1_pitch
        y1 = max(W, m4_track * m4_pitch + self.pdk['M4']['Width'] // 2,
                 (q + 1) * m4_pitch_for_m5_spg + self.pdk['M4']['Pitch'] - m4_pitch_for_m5_spg // 2)
        y1 = ((y1 + m2_pitch - 1) // m2_pitch) * m2_pitch
        self.addRegion(self.bbox_gen, 'Boundary', 0, 0, x1, y1)
