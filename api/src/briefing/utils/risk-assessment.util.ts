import {
  BriefingResponse,
  RiskLevel,
  RiskCategory,
  RiskSummary,
} from '../interfaces/briefing-response.interface';

/**
 * Compute a risk summary from the assembled briefing response.
 * Pure function — no side effects.
 */
export function computeRiskSummary(response: BriefingResponse): RiskSummary {
  const categories: RiskCategory[] = [
    assessWeather(response),
    assessIcing(response),
    assessTurbulence(response),
    assessThunderstorms(response),
    assessTfrs(response),
    assessNotams(response),
  ];

  const overallLevel = categories.reduce<RiskLevel>(
    (worst, cat) => mergeRisk(worst, cat.level),
    'green',
  );

  // Collect critical items: all alerts from red + yellow categories, max 5
  const criticalItems: string[] = [];
  for (const cat of categories) {
    if (cat.level === 'red') criticalItems.push(...cat.alerts);
  }
  for (const cat of categories) {
    if (cat.level === 'yellow') criticalItems.push(...cat.alerts);
  }

  return {
    overallLevel,
    categories,
    criticalItems: criticalItems.slice(0, 5),
  };
}

function mergeRisk(a: RiskLevel, b: RiskLevel): RiskLevel {
  const order: Record<RiskLevel, number> = { green: 0, yellow: 1, red: 2 };
  return order[a] >= order[b] ? a : b;
}

function assessWeather(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';

  const metars = response.currentWeather.metars;
  const depMetar = metars.find((m) => m.section === 'departure');
  const destMetar = metars.find((m) => m.section === 'destination');

  // Check destination
  if (destMetar?.flightCategory) {
    const cat = destMetar.flightCategory.toUpperCase();
    if (cat === 'IFR' || cat === 'LIFR') {
      level = 'red';
      alerts.push(`Destination ${destMetar.icaoId} reporting ${cat}`);
    } else if (cat === 'MVFR') {
      level = mergeRisk(level, 'yellow');
      alerts.push(`Destination ${destMetar.icaoId} reporting MVFR`);
    }
  }

  // Check destination TAF at ETA
  const destTaf = response.forecasts.tafs.find(
    (t) => t.section === 'destination',
  );
  if (destTaf?.fcsts?.length) {
    const etaIso = response.flight.eta;
    const forecastAtEta = etaIso
      ? findForecastPeriod(destTaf.fcsts, etaIso)
      : null;
    if (forecastAtEta?.fltCat) {
      const fcat = forecastAtEta.fltCat.toUpperCase();
      if (fcat === 'IFR' || fcat === 'LIFR') {
        level = mergeRisk(level, 'red');
        alerts.push(`Dest ${destTaf.icaoId} forecast ${fcat} at ETA`);
      } else if (fcat === 'MVFR') {
        level = mergeRisk(level, 'yellow');
        alerts.push(`Dest ${destTaf.icaoId} forecast MVFR at ETA`);
      }
    }
  }

  // Check departure
  if (depMetar?.flightCategory) {
    const cat = depMetar.flightCategory.toUpperCase();
    if (cat === 'IFR' || cat === 'LIFR') {
      level = mergeRisk(level, 'red');
      alerts.push(`Departure ${depMetar.icaoId} reporting ${cat}`);
    } else if (cat === 'MVFR') {
      level = mergeRisk(level, 'yellow');
      alerts.push(`Departure ${depMetar.icaoId} reporting MVFR`);
    }
  }

  return { category: 'weather', level, alerts };
}

function assessIcing(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';
  const airmets = response.adverseConditions.airmets;

  const icingAdvisories = [
    ...airmets.icing,
    ...response.adverseConditions.sigmets.filter((s) =>
      s.hazardType.toLowerCase().includes('ice'),
    ),
  ];

  for (const adv of icingAdvisories) {
    if (adv.altitudeRelation === 'within') {
      level = 'red';
      alerts.push(adv.plainEnglish || `Icing advisory within cruise altitude`);
    } else if (
      adv.altitudeRelation === 'above' ||
      adv.altitudeRelation === 'below'
    ) {
      level = mergeRisk(level, 'yellow');
      if (alerts.length === 0) {
        alerts.push(
          adv.plainEnglish ||
            `Icing advisory near route (${adv.altitudeRelation} cruise)`,
        );
      }
    } else if (adv.altitudeRelation == null) {
      // No altitude info, be cautious
      level = mergeRisk(level, 'yellow');
      if (alerts.length === 0) {
        alerts.push(adv.plainEnglish || 'Icing advisory on route');
      }
    }
  }

  return { category: 'icing', level, alerts };
}

function assessTurbulence(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';
  const airmets = response.adverseConditions.airmets;

  const turbAdvisories = [...airmets.turbulenceLow, ...airmets.turbulenceHigh];

  // Check SIGMETs for turbulence
  const turbSigmets = response.adverseConditions.sigmets.filter((s) =>
    s.hazardType.toLowerCase().includes('turb'),
  );

  for (const sig of turbSigmets) {
    if (sig.altitudeRelation === 'within') {
      level = 'red';
      alerts.push(
        sig.plainEnglish || 'SIGMET turbulence within cruise altitude',
      );
    }
  }

  // UUA (urgent) PIREPs for turbulence
  const uuaPireps = response.adverseConditions.urgentPireps.filter(
    (p) => p.turbulence,
  );
  if (uuaPireps.length > 0) {
    level = mergeRisk(level, 'red');
    alerts.push(`${uuaPireps.length} urgent turbulence PIREP(s) on route`);
  }

  for (const adv of turbAdvisories) {
    if (adv.altitudeRelation === 'within') {
      level = mergeRisk(level, 'yellow');
      if (alerts.length === 0) {
        alerts.push(adv.plainEnglish || 'AIRMET turbulence on route');
      }
    }
  }

  return { category: 'turbulence', level, alerts };
}

function assessThunderstorms(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';
  const convSigmets = response.adverseConditions.convectiveSigmets;

  if (convSigmets.length > 0) {
    // Check if any have affected segment (meaning they're on route)
    const onRoute = convSigmets.filter((s) => s.affectedSegment != null);
    if (onRoute.length > 0) {
      level = 'red';
      for (const sig of onRoute.slice(0, 2)) {
        alerts.push(sig.plainEnglish || 'Convective SIGMET on route');
      }
    } else {
      level = 'yellow';
      alerts.push(`${convSigmets.length} convective SIGMET(s) near route`);
    }
  }

  return { category: 'thunderstorms', level, alerts };
}

function assessTfrs(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';
  const tfrs = response.adverseConditions.tfrs;

  if (tfrs.length > 0) {
    level = 'red';
    for (const tfr of tfrs.slice(0, 2)) {
      alerts.push(`TFR active: ${tfr.description || tfr.notamNumber}`);
    }
    if (tfrs.length > 2) {
      alerts.push(`...and ${tfrs.length - 2} more TFR(s)`);
    }
  }

  return { category: 'tfrs', level, alerts };
}

function assessNotams(response: BriefingResponse): RiskCategory {
  const alerts: string[] = [];
  let level: RiskLevel = 'green';
  const closedNotams = response.adverseConditions.closedUnsafeNotams;

  for (const notam of closedNotams) {
    const text = (notam.text || notam.fullText || '').toUpperCase();
    if (text.includes('RWY') || text.includes('RUNWAY')) {
      level = 'red';
      alerts.push(
        `Runway closure: ${notam.icaoId} - ${notam.text.slice(0, 60)}`,
      );
    } else if (text.includes('TWY') || text.includes('TAXIWAY')) {
      level = mergeRisk(level, 'yellow');
      if (alerts.length < 2) {
        alerts.push(
          `Taxiway closure: ${notam.icaoId} - ${notam.text.slice(0, 60)}`,
        );
      }
    } else {
      level = mergeRisk(level, 'yellow');
    }
  }

  return { category: 'notams', level, alerts };
}

function findForecastPeriod(
  fcsts: { timeFrom: string; timeTo: string; fltCat: string | null }[],
  etaIso: string,
): { fltCat: string | null } | null {
  if (!fcsts || fcsts.length === 0) return null;

  const eta = new Date(etaIso).getTime();
  if (isNaN(eta)) return null;

  // Walk periods in reverse to find most specific match
  for (let i = fcsts.length - 1; i >= 0; i--) {
    const from = new Date(fcsts[i].timeFrom).getTime();
    const to = new Date(fcsts[i].timeTo).getTime();
    if (!isNaN(from) && !isNaN(to) && eta >= from && eta <= to) {
      return fcsts[i];
    }
  }

  // Fall back to last period
  return fcsts[fcsts.length - 1];
}
