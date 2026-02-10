import { useState } from 'react'
import { motion } from 'framer-motion'
import { Check } from 'lucide-react'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'
import { Button } from '../Button'

const features = [
  'Vector charts at 60fps',
  'Real-time weather & radar',
  'Flight planning & routing',
  'Weight & balance calculator',
  'Digital logbook with sync',
  'Avionics integration (ADS-B)',
  'Cross-platform (iOS + Android)',
  'Unlimited aircraft profiles',
  'Offline charts & data',
]

export function Pricing() {
  const [annual, setAnnual] = useState(true)
  const { ref, isInView } = useScrollAnimation()

  const monthlyPrice = annual ? 8.25 : 9.99
  const annualTotal = 99

  return (
    <section id="pricing" className="section-padding bg-[var(--color-warm-white)]">
      <motion.div
        ref={ref}
        className="container mx-auto max-w-[1280px] px-8 lg:px-12"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <motion.div variants={fadeUp} transition={{ duration: 0.5 }} className="text-center mb-12">
          <h2 className="headline-section text-[var(--color-deep-slate)]">
            One plan. Everything included.
          </h2>
          <p className="text-body text-[var(--color-slate)] mt-4 max-w-xl mx-auto">
            No surprise tier upgrades. What you see is what you get.
          </p>
        </motion.div>

        {/* Toggle */}
        <motion.div variants={fadeUp} transition={{ duration: 0.5 }} className="flex justify-center mb-12">
          <div className="inline-flex items-center bg-white rounded-full p-1 border border-slate-200 gap-1">
            <button
              onClick={() => setAnnual(false)}
              className={`px-5 py-2 rounded-full text-sm font-medium transition-all cursor-pointer ${!annual ? 'bg-[var(--color-navy)] text-white shadow-sm' : 'text-[var(--color-slate)] hover:text-[var(--color-deep-slate)]'
                }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setAnnual(true)}
              className={`px-5 py-2 rounded-full text-sm font-medium transition-all cursor-pointer flex items-center gap-2 ${annual ? 'bg-[var(--color-navy)] text-white shadow-sm' : 'text-[var(--color-slate)] hover:text-[var(--color-deep-slate)]'
                }`}
            >
              Annual
              <span className="text-[var(--color-teal)] text-xs font-semibold">Save 17%</span>
            </button>
          </div>
        </motion.div>

        {/* Pricing card */}
        <motion.div
          variants={fadeUp}
          transition={{ duration: 0.5 }}
          className="max-w-md mx-auto"
        >
          <div className="bg-white rounded-2xl border border-slate-200 p-8 shadow-sm">
            <div className="text-center mb-6">
              <span className="text-xs font-semibold text-[var(--color-teal)] uppercase tracking-widest">
                Tropiq Pro
              </span>
              <div className="mt-3 flex items-baseline justify-center gap-1">
                <span className="text-5xl font-bold text-[var(--color-deep-slate)]">
                  ${monthlyPrice.toFixed(2)}
                </span>
                <span className="text-[var(--color-slate)] text-lg">/mo</span>
              </div>
              {annual && (
                <p className="text-sm text-[var(--color-slate)] mt-1.5">
                  ${annualTotal}/year, billed annually
                </p>
              )}
            </div>

            <ul className="space-y-3 mb-8">
              {features.map((feature) => (
                <li key={feature} className="flex items-center gap-3">
                  <div className="w-5 h-5 rounded-full bg-[var(--color-teal)]/10 flex items-center justify-center flex-shrink-0">
                    <Check size={12} className="text-[var(--color-teal)]" />
                  </div>
                  <span className="text-[15px] text-[var(--color-deep-slate)]">{feature}</span>
                </li>
              ))}
            </ul>

            <Button size="lg" className="w-full justify-center">
              Get Early Access
            </Button>

            <p className="text-center text-xs text-[var(--color-slate)] mt-3">
              14-day free trial. No credit card required.
            </p>
          </div>
        </motion.div>
      </motion.div>
    </section>
  )
}
