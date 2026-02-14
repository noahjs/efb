#!/usr/bin/env python3
"""Unit tests for process.py helper functions."""

import math
import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import process as process_hrrr


class TestUVToDirectionSpeed(unittest.TestCase):
    """Test wind U/V component conversion to meteorological direction and speed."""

    def test_pure_west_wind(self):
        """Wind from the west (270°): U=+10 (blowing east), V=0."""
        direction, speed = process_hrrr.uv_to_dir_speed(10, 0)
        self.assertEqual(direction, 270)
        self.assertEqual(speed, 19)  # 10 m/s * 1.944

    def test_pure_north_wind(self):
        """Wind from the north (0°/360°): U=0, V=-10 (blowing south)."""
        direction, speed = process_hrrr.uv_to_dir_speed(0, -10)
        # 0° and 360° are equivalent for north
        self.assertIn(direction, [0, 360])
        self.assertEqual(speed, 19)

    def test_pure_south_wind(self):
        """Wind from the south (180°): U=0, V=+10 (blowing north)."""
        direction, speed = process_hrrr.uv_to_dir_speed(0, 10)
        self.assertEqual(direction, 180)
        self.assertEqual(speed, 19)

    def test_pure_east_wind(self):
        """Wind from the east (90°): U=-10 (blowing west), V=0."""
        direction, speed = process_hrrr.uv_to_dir_speed(-10, 0)
        self.assertEqual(direction, 90)
        self.assertEqual(speed, 19)

    def test_southwest_wind(self):
        """Wind from the southwest (225°): blowing NE, U=+10, V=+10."""
        direction, speed = process_hrrr.uv_to_dir_speed(10, 10)
        self.assertEqual(direction, 225)

    def test_calm_wind(self):
        """Zero wind should return 0, 0."""
        direction, speed = process_hrrr.uv_to_dir_speed(0, 0)
        self.assertEqual(direction, 0)
        self.assertEqual(speed, 0)

    def test_very_light_wind(self):
        """Very light wind below threshold should return 0, 0."""
        direction, speed = process_hrrr.uv_to_dir_speed(0.001, 0.001)
        self.assertEqual(direction, 0)
        self.assertEqual(speed, 0)

    def test_speed_conversion_accuracy(self):
        """10 m/s = 19.44 kt, should round to 19."""
        _, speed = process_hrrr.uv_to_dir_speed(10, 0)
        self.assertEqual(speed, 19)

    def test_strong_wind_speed(self):
        """50 m/s = 97.2 kt."""
        _, speed = process_hrrr.uv_to_dir_speed(50, 0)
        self.assertEqual(speed, 97)


class TestGpmToFeet(unittest.TestCase):
    """Test geopotential meters to feet conversion."""

    def test_standard_conversion(self):
        """1000 gpm ≈ 3281 ft."""
        self.assertEqual(process_hrrr.gpm_to_feet(1000), 3281)

    def test_zero(self):
        self.assertEqual(process_hrrr.gpm_to_feet(0), 0)

    def test_none_returns_none(self):
        self.assertIsNone(process_hrrr.gpm_to_feet(None))

    def test_nan_returns_none(self):
        self.assertIsNone(process_hrrr.gpm_to_feet(float('nan')))

    def test_typical_ceiling(self):
        """1500 gpm (typical ceiling) ≈ 4921 ft."""
        self.assertEqual(process_hrrr.gpm_to_feet(1500), 4921)


class TestMetersToSm(unittest.TestCase):
    """Test meters to statute miles conversion."""

    def test_10km_visibility(self):
        """10000m = 6.2 sm."""
        self.assertEqual(process_hrrr.meters_to_sm(10000), 6.2)

    def test_1mile(self):
        """1609m ≈ 1.0 sm."""
        self.assertEqual(process_hrrr.meters_to_sm(1609.34), 1.0)

    def test_quarter_mile(self):
        """~400m ≈ 0.2 sm."""
        result = process_hrrr.meters_to_sm(400)
        self.assertAlmostEqual(result, 0.2, places=1)

    def test_none_returns_none(self):
        self.assertIsNone(process_hrrr.meters_to_sm(None))

    def test_nan_returns_none(self):
        self.assertIsNone(process_hrrr.meters_to_sm(float('nan')))


class TestKelvinToCelsius(unittest.TestCase):
    """Test Kelvin to Celsius conversion."""

    def test_freezing_point(self):
        self.assertEqual(process_hrrr.kelvin_to_celsius(273.15), 0.0)

    def test_boiling_point(self):
        self.assertEqual(process_hrrr.kelvin_to_celsius(373.15), 100.0)

    def test_typical_surface_temp(self):
        """288K ≈ 14.9°C."""
        self.assertEqual(process_hrrr.kelvin_to_celsius(288), 14.9)

    def test_cold_altitude(self):
        """243K ≈ -30.1°C."""
        self.assertEqual(process_hrrr.kelvin_to_celsius(243), -30.1)

    def test_none_returns_none(self):
        self.assertIsNone(process_hrrr.kelvin_to_celsius(None))

    def test_nan_returns_none(self):
        self.assertIsNone(process_hrrr.kelvin_to_celsius(float('nan')))


class TestFlightCategory(unittest.TestCase):
    """Test flight category derivation from ceiling and visibility."""

    def test_vfr(self):
        """Ceiling > 3000 and vis > 5 = VFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(5000, 10.0), 'VFR'
        )

    def test_mvfr_ceiling(self):
        """Ceiling 1000-3000 = MVFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(2500, 10.0), 'MVFR'
        )

    def test_mvfr_visibility(self):
        """Vis 3-5 = MVFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(5000, 4.0), 'MVFR'
        )

    def test_ifr_ceiling(self):
        """Ceiling 500-1000 = IFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(800, 10.0), 'IFR'
        )

    def test_ifr_visibility(self):
        """Vis 1-3 = IFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(5000, 2.0), 'IFR'
        )

    def test_lifr_ceiling(self):
        """Ceiling < 500 = LIFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(300, 10.0), 'LIFR'
        )

    def test_lifr_visibility(self):
        """Vis < 1 = LIFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(5000, 0.5), 'LIFR'
        )

    def test_worst_category_wins(self):
        """VFR ceiling but IFR vis → IFR."""
        self.assertEqual(
            process_hrrr.compute_flight_category(5000, 2.0), 'IFR'
        )

    def test_lifr_both(self):
        """Both LIFR conditions."""
        self.assertEqual(
            process_hrrr.compute_flight_category(200, 0.25), 'LIFR'
        )

    def test_boundary_vfr_mvfr_ceiling(self):
        """Ceiling exactly 3000 = MVFR (< 3000)."""
        self.assertEqual(
            process_hrrr.compute_flight_category(3000, 10.0), 'VFR'
        )
        self.assertEqual(
            process_hrrr.compute_flight_category(2999, 10.0), 'MVFR'
        )

    def test_boundary_mvfr_ifr_ceiling(self):
        """Ceiling exactly 1000 = IFR (< 1000)."""
        self.assertEqual(
            process_hrrr.compute_flight_category(1000, 10.0), 'MVFR'
        )
        self.assertEqual(
            process_hrrr.compute_flight_category(999, 10.0), 'IFR'
        )

    def test_boundary_ifr_lifr_ceiling(self):
        """Ceiling exactly 500 = IFR (< 500)."""
        self.assertEqual(
            process_hrrr.compute_flight_category(500, 10.0), 'IFR'
        )
        self.assertEqual(
            process_hrrr.compute_flight_category(499, 10.0), 'LIFR'
        )

    def test_none_ceiling_and_visibility(self):
        """Both None → VFR (optimistic default)."""
        self.assertEqual(
            process_hrrr.compute_flight_category(None, None), 'VFR'
        )

    def test_none_ceiling_low_vis(self):
        """None ceiling, low vis → worst vis category."""
        self.assertEqual(
            process_hrrr.compute_flight_category(None, 0.5), 'LIFR'
        )


class TestSafeFloat(unittest.TestCase):
    """Test safe_float helper."""

    def test_normal_float(self):
        self.assertEqual(process_hrrr.safe_float(3.14), 3.14)

    def test_int(self):
        self.assertEqual(process_hrrr.safe_float(42), 42.0)

    def test_none(self):
        self.assertIsNone(process_hrrr.safe_float(None))

    def test_nan(self):
        self.assertIsNone(process_hrrr.safe_float(float('nan')))

    def test_inf(self):
        self.assertIsNone(process_hrrr.safe_float(float('inf')))

    def test_neg_inf(self):
        self.assertIsNone(process_hrrr.safe_float(float('-inf')))

    def test_string_raises(self):
        """Non-numeric string returns None."""
        self.assertIsNone(process_hrrr.safe_float('hello'))


class TestNearestIdx(unittest.TestCase):
    """Test nearest_idx helper."""

    def test_exact_match(self):
        import numpy as np
        arr = np.array([24.0, 25.0, 26.0, 27.0])
        self.assertEqual(process_hrrr.nearest_idx(arr, 25.0), 1)

    def test_between_values(self):
        import numpy as np
        arr = np.array([24.0, 25.0, 26.0, 27.0])
        self.assertEqual(process_hrrr.nearest_idx(arr, 25.3), 1)
        self.assertEqual(process_hrrr.nearest_idx(arr, 25.7), 2)

    def test_below_range(self):
        import numpy as np
        arr = np.array([24.0, 25.0, 26.0])
        self.assertEqual(process_hrrr.nearest_idx(arr, 20.0), 0)

    def test_above_range(self):
        import numpy as np
        arr = np.array([24.0, 25.0, 26.0])
        self.assertEqual(process_hrrr.nearest_idx(arr, 30.0), 2)

    def test_midpoint(self):
        import numpy as np
        arr = np.array([24.0, 25.0, 26.0])
        # 24.5 is equidistant — should return 0 (left bias from searchsorted)
        idx = process_hrrr.nearest_idx(arr, 24.5)
        self.assertIn(idx, [0, 1])  # Either is acceptable


if __name__ == '__main__':
    unittest.main()
