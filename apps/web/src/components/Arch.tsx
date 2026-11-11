// The mihrab arch behind the next prayer and the surah title. The outline stretches to its box
// (preserveAspectRatio none, non-scaling strokes); the lattice and keystone keep their proportions.
const OUTER = 'M4 260V112C4 58 52 26 100 4c48 22 96 54 96 108v148Z'
const INNER = 'M14 260V116C14 68 56 38 100 18c44 20 86 50 86 98v144'
const BEADS = 'M21 260V119C21 75 59 47 100 28c41 19 79 47 79 91v141'

export function Arch() {
  return (
    <>
      <svg className="arch" viewBox="0 0 200 260" preserveAspectRatio="none" aria-hidden="true">
        <path className="arch-fill" d={OUTER} />
        <path className="arch-line" d={OUTER} />
        <path className="arch-inner" d={INNER} />
        <path className="arch-beads" d={BEADS} />
        {/* Capitals where the curve meets the straight sides. */}
        <path className="arch-line" d="M4 110H21M4 115H21M179 110H196M179 115H196" />
      </svg>
      <span className="arch-lattice" aria-hidden="true" />
      <svg className="arch-keystone" viewBox="-12 -12 24 24" aria-hidden="true">
        <rect x="-7" y="-7" width="14" height="14" />
        <rect x="-7" y="-7" width="14" height="14" transform="rotate(45)" />
        <circle r="2.2" />
      </svg>
    </>
  )
}
