import { useState } from 'react'
import { motion } from 'framer-motion'
import { ArrowRight } from 'lucide-react'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'
import { Button } from '../Button'

export function FinalCTA() {
  const [email, setEmail] = useState('')
  const { ref, isInView } = useScrollAnimation()

  return (
    <section className="section-padding bg-[var(--color-navy)] relative overflow-hidden">
      {/* Ambient glows */}
      <div className="absolute top-0 left-1/3 w-[500px] h-[300px] rounded-full bg-[var(--color-teal)]/5 blur-[120px]" />
      <div className="absolute bottom-0 right-1/4 w-[400px] h-[250px] rounded-full bg-[var(--color-sky)]/5 blur-[100px]" />

      <motion.div
        ref={ref}
        className="container relative mx-auto max-w-[1280px] px-8 lg:px-12 text-center"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <motion.h2
          variants={fadeUp}
          transition={{ duration: 0.5 }}
          className="headline-section text-white mb-5"
        >
          Ready to modernize your flight bag?
        </motion.h2>

        <motion.p
          variants={fadeUp}
          transition={{ duration: 0.5 }}
          className="text-body text-white/60 max-w-xl mx-auto mb-8"
        >
          Join thousands of pilots who are flying smarter. Get early access to Tropiq and be the first to experience the modern EFB.
        </motion.p>

        <motion.div
          variants={fadeUp}
          transition={{ duration: 0.5 }}
          className="flex flex-col sm:flex-row items-stretch justify-center gap-3 max-w-md mx-auto"
        >
          <input
            type="email"
            placeholder="you@pilot.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full sm:flex-1 px-4 py-3 rounded-lg bg-white/10 border border-white/15 text-white placeholder:text-white/30 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-teal)]/50 focus:border-transparent transition-all"
          />
          <Button size="lg" className="whitespace-nowrap">
            Get Early Access
            <ArrowRight size={15} className="ml-2" />
          </Button>
        </motion.div>

        <motion.p
          variants={fadeUp}
          transition={{ duration: 0.5 }}
          className="text-xs text-white/30 mt-4"
        >
          Free for early adopters. No credit card required.
        </motion.p>
      </motion.div>
    </section>
  )
}
