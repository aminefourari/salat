import { iso1A2Code } from '@rapideditor/country-coder'

/** ISO country at a point, from bundled world borders (~600 KB): import it from the Worker or tests, and only
 *  lazily in the browser (client.ts saves the country with the location; pages pass `loc.country`). */
export const countryAt = (lat: number, lon: number): string | null => iso1A2Code([lon, lat]) ?? null
