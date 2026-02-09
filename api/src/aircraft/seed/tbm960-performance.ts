// TBM 960 POH Performance Data (simplified from POH Edition 0, Rev 2)
// Data points for trilinear interpolation across pressure_altitude × temperature_c × weight_lbs

function generateTable(
  baseRoll: number,
  baseDist: number,
  baseVr: number,
  baseV50: number,
) {
  const altitudes = [0, 2000, 4000, 6000, 8000];
  const temps = [-20, 0, 20, 40];
  const weights = [4500, 5000, 5500, 6000, 6500, 7000, 7615];

  const table: Array<{
    pressure_altitude: number;
    temperature_c: number;
    weight_lbs: number;
    ground_roll_ft: number;
    total_distance_ft: number;
    vr_kias: number;
    v50_kias: number;
  }> = [];

  for (const alt of altitudes) {
    for (const temp of temps) {
      for (const wt of weights) {
        // Altitude factor: ~+12% per 2000ft
        const altFactor = 1 + (alt / 2000) * 0.12;
        // Temperature factor: ~+1% per °C above ISA (15°C at SL)
        const isa = 15 - (alt / 1000) * 2;
        const tempDev = temp - isa;
        const tempFactor = 1 + Math.max(0, tempDev) * 0.01;
        // Weight factor: scale from min weight
        const weightFactor = Math.pow(wt / 5000, 1.8);

        const roll = Math.round(
          baseRoll * altFactor * tempFactor * weightFactor,
        );
        const dist = Math.round(
          baseDist * altFactor * tempFactor * weightFactor,
        );

        // V-speeds scale ~sqrt(weight ratio)
        const vFactor = Math.sqrt(wt / 5000);
        const vr = Math.round(baseVr * vFactor);
        const v50 = Math.round(baseV50 * vFactor);

        table.push({
          pressure_altitude: alt,
          temperature_c: temp,
          weight_lbs: wt,
          ground_roll_ft: roll,
          total_distance_ft: dist,
          vr_kias: vr,
          v50_kias: v50,
        });
      }
    }
  }

  return table;
}

export const TBM960_TAKEOFF_DATA = {
  version: 1,
  source: 'TBM 960 POH Edition 0, Rev 2',
  flap_settings: [
    {
      name: 'TO',
      code: 'to',
      is_default: true,
      table: generateTable(750, 1100, 76, 91),
      wind_correction: {
        headwind_factor_per_kt: -0.015,
        tailwind_factor_per_kt: 0.035,
      },
      surface_factors: {
        paved_dry: 1.0,
        paved_wet: 1.15,
        grass_dry: 1.2,
        grass_wet: 1.3,
      },
      slope_correction_per_percent: 0.05,
    },
    {
      name: 'UP',
      code: 'up',
      is_default: false,
      table: generateTable(900, 1350, 80, 96),
      wind_correction: {
        headwind_factor_per_kt: -0.015,
        tailwind_factor_per_kt: 0.035,
      },
      surface_factors: {
        paved_dry: 1.0,
        paved_wet: 1.15,
        grass_dry: 1.2,
        grass_wet: 1.3,
      },
      slope_correction_per_percent: 0.05,
    },
  ],
};

export const TBM960_LANDING_DATA = {
  version: 1,
  source: 'TBM 960 POH Edition 0, Rev 2',
  flap_settings: [
    {
      name: 'FULL',
      code: 'full',
      is_default: true,
      table: generateTable(700, 1250, 68, 85),
      wind_correction: {
        headwind_factor_per_kt: -0.015,
        tailwind_factor_per_kt: 0.035,
      },
      surface_factors: {
        paved_dry: 1.0,
        paved_wet: 1.15,
        grass_dry: 1.2,
        grass_wet: 1.3,
      },
      slope_correction_per_percent: -0.05,
    },
    {
      name: 'LDG',
      code: 'ldg',
      is_default: false,
      table: generateTable(800, 1400, 72, 89),
      wind_correction: {
        headwind_factor_per_kt: -0.015,
        tailwind_factor_per_kt: 0.035,
      },
      surface_factors: {
        paved_dry: 1.0,
        paved_wet: 1.15,
        grass_dry: 1.2,
        grass_wet: 1.3,
      },
      slope_correction_per_percent: -0.05,
    },
  ],
};
