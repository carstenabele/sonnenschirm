// src/sun-math.mjs — pure Mathematik (kein DOM/Three)
export const DEG = Math.PI / 180;
export const RAD = 180 / Math.PI;

// Sonnenstand (kompakte NOAA/SunCalc-Variante).
// Azimut von Norden im Uhrzeigersinn, Höhe in Radiant.
export function sunPosition(date, lat, lng) {
  const dayMs = 86400000, J1970 = 2440588, J2000 = 2451545;
  const e = 23.4397 * DEG;
  const d = date.valueOf() / dayMs - 0.5 + J1970 - J2000;
  const M = (357.5291 + 0.98560028 * d) * DEG;
  const C = (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * DEG;
  const P = 102.9372 * DEG;
  const L = M + C + P + Math.PI;
  const dec = Math.asin(Math.sin(e) * Math.sin(L));
  const ra  = Math.atan2(Math.cos(e) * Math.sin(L), Math.cos(L));
  const lw  = -lng * DEG;
  const phi = lat * DEG;
  const theta = (280.16 + 360.9856235 * d) * DEG - lw;
  const H = theta - ra;
  const azS = Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
  let azN = azS + Math.PI;
  azN = (azN % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
  const alt = Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
  return { azimuth: azN, altitude: alt };
}

// Einheitsvektor zur Sonne. +X Ost, +Y oben, −Z Nord.
export function sunVector(azN, alt) {
  const ch = Math.cos(alt);
  return {
    x: Math.sin(azN) * ch,
    y: Math.sin(alt),
    z: -Math.cos(azN) * ch,
  };
}
