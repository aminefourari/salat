export type MethodId =
  | 'aachen' | 'morocco' | 'mwl' | 'ummalqura' | 'uoif' | 'isna' | 'egyptian'
  | 'karachi' | 'dubai' | 'kuwait' | 'qatar' | 'singapore' | 'turkey' | 'tehran'

export const METHOD_IDS: MethodId[] = [
  'aachen', 'morocco', 'mwl', 'ummalqura', 'uoif', 'isna', 'egyptian',
  'karachi', 'dubai', 'kuwait', 'qatar', 'singapore', 'turkey', 'tehran',
]

// One entry per country; anything missing falls back to Muslim World League.
const BY_COUNTRY: Record<string, MethodId> = {
  DE: 'aachen', MA: 'morocco', SA: 'ummalqura', FR: 'uoif', US: 'isna', CA: 'isna',
  EG: 'egyptian', PK: 'karachi', AE: 'dubai', KW: 'kuwait', QA: 'qatar',
  SG: 'singapore', MY: 'singapore', ID: 'singapore', TR: 'turkey', IR: 'tehran',
}

export const methodForCountry = (iso2: string | null): MethodId => (iso2 && BY_COUNTRY[iso2]) || 'mwl'

