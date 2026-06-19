import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  sunPosition, sunVector, RAD,
  projectToGround, polygonArea, rectCornersWorld,
  shadowMetrics, mastShadowLength,
} from '../src/sun-math.mjs';

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

test('polygonArea: Einheitsquadrat = 1', () => {
  const sq = [{x:0,z:0},{x:1,z:0},{x:1,z:1},{x:0,z:1}];
  assert.ok(Math.abs(polygonArea(sq) - 1) < 1e-9);
});

test('projectToGround: senkrecht von oben projiziert auf gleiche x/z', () => {
  const g = projectToGround({x:2,y:3,z:-4}, {x:0,y:1,z:0}, -1.5);
  assert.ok(Math.abs(g.x - 2) < 1e-9 && Math.abs(g.z - (-4)) < 1e-9);
});

test('Ankerfall: L=4,B=2,Yaw=90,Neigung=0,Zenit → Fläche ~8 m²', () => {
  const az = 0, alt = Math.PI / 2; // Zenit
  const m = shadowMetrics({
    L: 4, B: 2, yawDeg: 90, tiltDeg: 0, tiltDirDeg: 0,
    height: 2.4, eye: 1.5, front: 4.0, azimuthRad: az, altitudeRad: alt,
  });
  assert.equal(m.isNight, false);
  assert.ok(Math.abs(m.areaM2 - 8) / 8 < 0.05, `Fläche ${m.areaM2.toFixed(2)} != ~8`);
});

test('Ankerfall: Fläche unabhängig vom Yaw (Zenit, Neigung 0)', () => {
  const base = { L:4, B:2, tiltDeg:0, tiltDirDeg:0, height:2.4, eye:1.5, front:4.0, azimuthRad:0, altitudeRad:Math.PI/2 };
  const a0 = shadowMetrics({ ...base, yawDeg: 0 }).areaM2;
  const a90 = shadowMetrics({ ...base, yawDeg: 90 }).areaM2;
  assert.ok(Math.abs(a0 - a90) / a0 < 0.05);
});

test('mastShadowLength ≈ Höhe / tan(Höhe)', () => {
  const altDeg = 30, alt = altDeg / RAD;
  const len = mastShadowLength(2.4, alt);
  const ref = 2.4 / Math.tan(alt);
  assert.ok(Math.abs(len - ref) / ref < 0.05);
});

test('Nacht: Sonne unter Horizont → isNight true', () => {
  const m = shadowMetrics({
    L:4, B:2, yawDeg:0, tiltDeg:0, tiltDirDeg:0,
    height:2.4, eye:1.5, front:4.0, azimuthRad:0, altitudeRad: -0.2,
  });
  assert.equal(m.isNight, true);
});
