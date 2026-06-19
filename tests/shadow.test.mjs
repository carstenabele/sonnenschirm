import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sunPosition, sunVector, RAD } from '../src/sun-math.mjs';

const LAT = 50.11, LNG = 8.68; // Frankfurt

function maxAltitudeOfDay(year, monthIdx, day, lat, lng) {
  let best = { altitude: -Infinity, azimuth: 0 };
  for (let m = 0; m < 1440; m += 1) {
    const date = new Date(Date.UTC(year, monthIdx, day, 0, m, 0));
    const p = sunPosition(date, lat, lng);
    if (p.altitude > best.altitude) best = p;
  }
  return best;
}

test('Sommersonnenwende: Mittagshöhe ~63.33°, Azimut ~Süden', () => {
  const peak = maxAltitudeOfDay(2026, 5, 21, LAT, LNG); // 21.06.2026
  const altDeg = peak.altitude * RAD;
  const azDeg = peak.azimuth * RAD;
  assert.ok(Math.abs(altDeg - 63.33) < 1, `Höhe ${altDeg.toFixed(2)}° != ~63.33°`);
  assert.ok(Math.abs(azDeg - 180) < 1, `Azimut ${azDeg.toFixed(2)}° != ~180°`);
});

test('Wintersonnenwende deutlich niedriger als Sommer', () => {
  const summer = maxAltitudeOfDay(2026, 5, 21, LAT, LNG).altitude * RAD;
  const winter = maxAltitudeOfDay(2026, 11, 21, LAT, LNG).altitude * RAD;
  assert.ok(summer - winter > 40, `Differenz ${(summer - winter).toFixed(1)}° zu klein`);
});

test('sunVector: Sonne im Zenit zeigt gerade nach oben', () => {
  const v = sunVector(0, Math.PI / 2);
  assert.ok(Math.abs(v.x) < 1e-9 && Math.abs(v.z) < 1e-9, 'x,z ~0');
  assert.ok(Math.abs(v.y - 1) < 1e-9, 'y ~1');
});

test('sunVector: Sonne im Osten am Horizont', () => {
  const v = sunVector(Math.PI / 2, 0); // Azimut 90° = Ost, Höhe 0
  assert.ok(Math.abs(v.x - 1) < 1e-9, 'x ~1 (Ost)');
  assert.ok(Math.abs(v.y) < 1e-9, 'y ~0');
});
