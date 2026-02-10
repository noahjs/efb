import { motion } from 'framer-motion'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'
import { Button } from '../Button'

export function CrossPlatform() {
  const { ref, isInView } = useScrollAnimation()

  return (
    <section className="section-padding bg-[var(--color-navy)] relative overflow-hidden">
      {/* Ambient glow */}
      <div className="absolute top-1/2 left-1/4 -translate-y-1/2 w-[400px] h-[400px] rounded-full bg-[var(--color-teal)]/5 blur-[100px]" />
      <div className="absolute bottom-0 right-1/4 w-[300px] h-[300px] rounded-full bg-[var(--color-sky)]/5 blur-[100px]" />

      <motion.div
        ref={ref}
        className="container relative mx-auto max-w-[1280px] px-8 lg:px-12"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Copy */}
          <div>
            <motion.h2
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="headline-section text-white mb-5"
            >
              Fly with the device you already own.
            </motion.h2>
            <motion.p
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="text-body text-white/60 mb-5 max-w-lg"
            >
              Full feature parity on iOS and Android. Your flight plans, aircraft profiles, and logbook sync seamlessly across every device. No more being locked into one platform.
            </motion.p>
            <motion.p
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="text-body text-white/60 mb-8 max-w-lg"
            >
              Switch between your iPad in the cockpit and your Android phone on the ramp. Everything stays in sync, always up to date.
            </motion.p>
            <motion.div variants={fadeUp} transition={{ duration: 0.5 }}>
              <Button size="lg">Get Early Access</Button>
            </motion.div>
          </div>

          {/* Device mockups */}
          <motion.div
            variants={fadeUp}
            transition={{ duration: 0.6 }}
            className="relative flex items-center justify-center gap-6"
          >
            {/* iPad */}
            <div className="w-[240px] h-[340px] rounded-[16px] bg-gradient-to-br from-white/10 to-white/5 border border-white/10 p-2 shadow-2xl shadow-black/30">
              <div className="w-full h-full rounded-[10px] bg-[#0d1f3c] flex flex-col items-center justify-center">
                <div className="w-8 h-8 rounded-lg bg-[var(--color-teal)]/20 flex items-center justify-center mb-3">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--color-teal)" strokeWidth="2">
                    <rect x="2" y="3" width="20" height="14" rx="2" />
                    <path d="M8 21h8M12 17v4" />
                  </svg>
                </div>
                <span className="font-mono text-[10px] text-white/30">iPad</span>
                <div className="mt-4 w-3/4 space-y-2">
                  <div className="h-1.5 rounded bg-white/10 w-full" />
                  <div className="h-1.5 rounded bg-white/10 w-4/5" />
                  <div className="h-1.5 rounded bg-[var(--color-teal)]/20 w-2/3" />
                </div>
              </div>
            </div>

            {/* Phone */}
            <div className="w-[140px] h-[280px] rounded-[20px] bg-gradient-to-br from-white/10 to-white/5 border border-white/10 p-1.5 shadow-2xl shadow-black/30 mt-10">
              <div className="w-full h-full rounded-[14px] bg-[#0d1f3c] flex flex-col items-center justify-center">
                <div className="w-6 h-6 rounded bg-[var(--color-sky)]/20 flex items-center justify-center mb-3">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--color-sky)" strokeWidth="2">
                    <rect x="5" y="2" width="14" height="20" rx="2" />
                    <path d="M12 18h.01" />
                  </svg>
                </div>
                <span className="font-mono text-[10px] text-white/30">Android</span>
                <div className="mt-4 w-3/4 space-y-2">
                  <div className="h-1 rounded bg-white/10 w-full" />
                  <div className="h-1 rounded bg-white/10 w-4/5" />
                  <div className="h-1 rounded bg-[var(--color-sky)]/20 w-2/3" />
                </div>
              </div>
            </div>

            {/* Sync indicator */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
              <div className="w-10 h-10 rounded-full bg-[var(--color-navy)] border border-white/20 flex items-center justify-center">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--color-teal)" strokeWidth="2" strokeLinecap="round">
                  <path d="M17 1l4 4-4 4" />
                  <path d="M3 11V9a4 4 0 0 1 4-4h14" />
                  <path d="M7 23l-4-4 4-4" />
                  <path d="M21 13v2a4 4 0 0 1-4 4H3" />
                </svg>
              </div>
            </div>
          </motion.div>
        </div>
      </motion.div>
    </section>
  )
}
