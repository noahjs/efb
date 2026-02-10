export function Footer() {
  const columns = [
    {
      title: 'Product',
      links: ['Features', 'Pricing', 'Download', 'Changelog'],
    },
    {
      title: 'Resources',
      links: ['Weather', 'Blog', 'Docs', 'Status'],
    },
    {
      title: 'Company',
      links: ['About', 'Careers', 'Press', 'Contact'],
    },
    {
      title: 'Legal',
      links: ['Privacy', 'Terms'],
    },
  ]

  return (
    <footer className="bg-[var(--color-deep-slate)] text-white/60">
      <div className="container mx-auto max-w-[1280px] px-8 lg:px-12 py-14">
        <div className="grid grid-cols-2 md:grid-cols-5 gap-8">
          {/* Brand column */}
          <div className="col-span-2 md:col-span-1">
            <a href="/" className="text-white text-lg font-bold tracking-[-0.03em]">
              TROPIQ
            </a>
            <p className="mt-3 text-sm leading-relaxed">
              The modern electronic flight bag for general aviation pilots.
            </p>
          </div>

          {/* Link columns */}
          {columns.map((col) => (
            <div key={col.title}>
              <h4 className="text-white text-xs font-semibold uppercase tracking-wider mb-4">
                {col.title}
              </h4>
              <ul className="space-y-2.5">
                {col.links.map((link) => (
                  <li key={link}>
                    <a
                      href="#"
                      className="text-sm hover:text-[var(--color-teal)] transition-colors"
                    >
                      {link}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="mt-12 pt-6 border-t border-white/10 flex flex-col md:flex-row items-center justify-between gap-3">
          <p className="text-xs">© {new Date().getFullYear()} Tropiq. All rights reserved.</p>
          <p className="text-xs italic">Built by pilots, for pilots.</p>
        </div>
      </div>
    </footer>
  )
}
