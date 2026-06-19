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

// 2D-Rotation in der x/z-Ebene um Winkel a (rad), positiv im UZS um +Y.
function rotY(p, a) {
  const c = Math.cos(a), s = Math.sin(a);
  return { x: p.x * c + p.z * s, y: p.y, z: -p.x * s + p.z * c };
}
// Rotation um X-Achse um Winkel a (rad).
function rotX(p, a) {
  const c = Math.cos(a), s = Math.sin(a);
  return { x: p.x, y: p.y * c - p.z * s, z: p.y * s + p.z * c };
}

// Vier Welt-Eckpunkte des Dach-Rechtecks nach Yaw → Neigungsrichtung → Neigung.
export function rectCornersWorld({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front }) {
  const yaw = yawDeg * DEG, dir = tiltDirDeg * DEG, tip = tiltDeg * DEG;
  const hx = L / 2, hz = B / 2;
  const local = [
    { x:  hx, y: 0, z:  hz },
    { x:  hx, y: 0, z: -hz },
    { x: -hx, y: 0, z: -hz },
    { x: -hx, y: 0, z:  hz },
  ];
  const topY = -eye + height;
  return local.map((p) => {
    // Reihenfolge: Yaw → Neigungsrichtung → Neigungswinkel
    let q = rotY(p, yaw);
    q = rotY(q, dir);
    q = rotX(q, tip);
    return { x: q.x, y: q.y + topY, z: q.z - front };
  });
}

// Projektion eines Punktes entlang des Sonnenvektors auf die Bodenebene y = yGround.
export function projectToGround(p, sunVec, yGround) {
  const t = (p.y - yGround) / sunVec.y;
  return { x: p.x - sunVec.x * t, z: p.z - sunVec.z * t };
}

// Fläche eines Polygons in der x/z-Ebene (Shoelace, immer ≥ 0).
export function polygonArea(pts) {
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.x * q.z - q.x * p.z;
  }
  return Math.abs(a) / 2;
}

// Schattenlänge des Masts: Höhe / tan(Sonnenhöhe).
export function mastShadowLength(height, altitudeRad) {
  if (altitudeRad <= 0) return Infinity;
  return height / Math.tan(altitudeRad);
}

// Numerische Schattenkennwerte des Dachs (Fläche + Mastlänge).
export function shadowMetrics({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front, azimuthRad, altitudeRad }) {
  if (altitudeRad <= 0) return { areaM2: 0, lengthM: Infinity, isNight: true };
  const sv = sunVector(azimuthRad, altitudeRad);
  const yGround = -eye;
  const corners = rectCornersWorld({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front });
  const ground = corners.map((c) => projectToGround(c, sv, yGround));
  return {
    areaM2: polygonArea(ground),
    lengthM: mastShadowLength(height, altitudeRad),
    isNight: false,
  };
}
