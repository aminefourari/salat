import data from './cities.data'

type Index = { names: string[]; cc: string[]; lat: Float32Array; lon: Float32Array }
let index: Index | undefined

function load(): Index {
  const lines = data.split('\n')
  const ix: Index = { names: [], cc: [], lat: new Float32Array(lines.length), lon: new Float32Array(lines.length) }
  lines.forEach((l, i) => {
    const [name, lat, lon, cc] = l.split('|')
    ix.names.push(name); ix.cc.push(cc); ix.lat[i] = +lat; ix.lon[i] = +lon
  })
  return ix
}

/** Nearest town (population ≥ 5000) within `maxKm`, or null. */
// ponytail: linear scan of 70k rows (~1 ms); add a grid index if it ever shows up in CPU time.
export function nearestCity(lat: number, lon: number, maxKm = 50): { name: string; country: string } | null {
  const ix = (index ??= load())
  const k = Math.cos((lat * Math.PI) / 180)
  let best = -1, bestD = Infinity
  for (let i = 0; i < ix.names.length; i++) {
    const dLat = ix.lat[i] - lat
    let dLon = Math.abs(ix.lon[i] - lon)
    if (dLon > 180) dLon = 360 - dLon
    const d = dLat * dLat + dLon * k * (dLon * k)
    if (d < bestD) { bestD = d; best = i }
  }
  const km = Math.sqrt(bestD) * 111.2
  return best < 0 || km > maxKm ? null : { name: ix.names[best], country: ix.cc[best] }
}
