import { motion } from 'framer-motion'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'

const stats = [
  { value: '5,000+', label: 'beta pilots' },
  { value: '60fps', label: 'rendering' },
  { value: 'iOS + Android', label: '' },
  { value: '4.9★', label: 'beta rating' },
]

export function SocialProof() {
  const { ref, isInView } = useScrollAnimation()

  return (
    <section className="bg-[var(--color-warm-white)] py-12 border-y border-slate-100">
      <motion.div
        ref={ref}
        className="container mx-auto max-w-[1280px] px-8 lg:px-12"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <div className="flex flex-wrap items-center justify-center gap-8 md:gap-0 md:divide-x md:divide-slate-200">
          {stats.map((stat) => (
            <motion.div
              key={stat.value}
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="flex items-center gap-2 px-6 md:px-10"
            >
              <span className="text-lg font-semibold text-[var(--color-deep-slate)]">
                {stat.value}
              </span>
              {stat.label && (
                <span className="text-sm text-[var(--color-slate)]">{stat.label}</span>
              )}
            </motion.div>
          ))}
        </div>
      </motion.div>
    </section>
  )
}
