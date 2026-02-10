import { motion } from 'framer-motion'
import { Button } from '../Button'

export function Hero() {
  return (
    <section className="relative flex items-center bg-[var(--color-navy)] overflow-hidden">
      {/* Subtle gradient overlay for depth */}
      <div className="absolute inset-0 bg-gradient-to-br from-[var(--color-navy)] via-[var(--color-navy)] to-[#0f2847] opacity-100" />

      {/* Subtle glow accent */}
      <div className="absolute top-1/4 right-1/4 w-[500px] h-[500px] rounded-full bg-[var(--color-teal)]/5 blur-[120px]" />

      <div className="container relative mx-auto max-w-[1280px] px-8 lg:px-12 pt-32 pb-20 lg:pt-40 lg:pb-28">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Left: Copy */}
          <div>
            <motion.h1
              className="headline-hero text-white mb-5"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.1 }}
            >
              Your flight bag,{' '}
              <span className="text-[var(--color-teal)]">finally modernized.</span>
            </motion.h1>

            <motion.p
              className="text-body text-white/60 max-w-lg mb-8"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.25 }}
            >
              Beautiful maps. Real-time weather. Transparent pricing. On iOS and Android.
            </motion.p>

            <motion.div
              className="flex flex-wrap gap-3"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.4 }}
            >
              <Button size="lg">Get Early Access</Button>
              <Button variant="secondary" size="lg" href="#features">
                See Features
              </Button>
            </motion.div>
          </div>

          {/* Right: App Mockup Placeholder */}
          <motion.div
            className="relative hidden lg:block"
            initial={{ opacity: 0, y: 40, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ duration: 0.8, delay: 0.5 }}
          >
            <div className="relative mx-auto w-[400px] h-[500px]">
              {/* Tablet mockup frame */}
              <div className="absolute inset-0 rounded-[24px] bg-gradient-to-br from-white/10 to-white/5 border border-white/10 backdrop-blur-sm shadow-2xl shadow-black/30 overflow-hidden">
                {/* Simulated app UI */}
                <div className="absolute inset-2 rounded-[18px] bg-[#0d1f3c] overflow-hidden">
                  {/* Status bar */}
                  <div className="h-8 bg-[#0a1628] flex items-center justify-between px-4">
                    <div className="flex gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-[var(--color-teal)]/60" />
                      <div className="w-2 h-2 rounded-full bg-[var(--color-sky)]/40" />
                    </div>
                    <span className="font-mono text-[10px] text-white/30">TROPIQ</span>
                    <div className="w-4" />
                  </div>

                  {/* Simulated map */}
                  <div className="relative h-full bg-gradient-to-b from-[#0d2240] to-[#0a1628]">
                    {/* Grid lines simulating chart */}
                    <svg className="absolute inset-0 w-full h-full" xmlns="http://www.w3.org/2000/svg">
                      {/* Latitude lines */}
                      <line x1="0" y1="25%" x2="100%" y2="25%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />
                      <line x1="0" y1="50%" x2="100%" y2="50%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />
                      <line x1="0" y1="75%" x2="100%" y2="75%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />
                      {/* Longitude lines */}
                      <line x1="25%" y1="0" x2="25%" y2="100%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />
                      <line x1="50%" y1="0" x2="50%" y2="100%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />
                      <line x1="75%" y1="0" x2="75%" y2="100%" stroke="rgba(56,189,248,0.08)" strokeWidth="0.5" />

                      {/* Route line */}
                      <path
                        d="M 80,340 C 120,270 200,210 290,140"
                        fill="none"
                        stroke="var(--color-teal)"
                        strokeWidth="2.5"
                        strokeLinecap="round"
                        opacity="0.9"
                      />
                      <path
                        d="M 80,340 C 120,270 200,210 290,140"
                        fill="none"
                        stroke="var(--color-teal)"
                        strokeWidth="8"
                        strokeLinecap="round"
                        opacity="0.1"
                      />

                      {/* Airport markers */}
                      <circle cx="80" cy="340" r="5" fill="var(--color-teal)" opacity="0.9" />
                      <circle cx="80" cy="340" r="10" fill="var(--color-teal)" opacity="0.15" />
                      <circle cx="290" cy="140" r="5" fill="var(--color-sky)" opacity="0.9" />
                      <circle cx="290" cy="140" r="10" fill="var(--color-sky)" opacity="0.15" />

                      {/* VOR symbol */}
                      <polygon points="185,255 191,243 179,243" fill="none" stroke="var(--color-sky)" strokeWidth="1" opacity="0.4" />
                    </svg>

                    {/* Airport labels */}
                    <div className="absolute font-mono text-[10px] text-[var(--color-teal)] font-medium" style={{ left: '50px', top: '344px' }}>
                      KSFO
                    </div>
                    <div className="absolute font-mono text-[10px] text-[var(--color-sky)] font-medium" style={{ left: '278px', top: '120px' }}>
                      KOAK
                    </div>

                    {/* Weather overlay blob */}
                    <div className="absolute w-32 h-32 rounded-full bg-[var(--color-vfr)]/8 blur-xl" style={{ left: '30%', top: '20%' }} />
                    <div className="absolute w-24 h-24 rounded-full bg-[var(--color-ifr)]/10 blur-xl" style={{ left: '60%', top: '50%' }} />

                    {/* Bottom info bar */}
                    <div className="absolute bottom-0 left-0 right-0 h-14 bg-gradient-to-t from-[#0a1628] to-transparent" />
                    <div className="absolute bottom-2 left-4 right-4 flex justify-between items-end">
                      <div>
                        <div className="font-mono text-[10px] text-white/30">ETE</div>
                        <div className="font-mono text-sm text-white/80">0:42</div>
                      </div>
                      <div>
                        <div className="font-mono text-[10px] text-white/30">DIST</div>
                        <div className="font-mono text-sm text-white/80">18nm</div>
                      </div>
                      <div>
                        <div className="font-mono text-[10px] text-white/30">GS</div>
                        <div className="font-mono text-sm text-white/80">112kt</div>
                      </div>
                      <div>
                        <div className="font-mono text-[10px] text-white/30">ALT</div>
                        <div className="font-mono text-sm text-white/80">4,500</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
