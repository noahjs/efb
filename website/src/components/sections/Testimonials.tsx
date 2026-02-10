import { motion } from 'framer-motion'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'

const testimonials = [
  {
    quote: "I've been using ForeFlight for eight years, and Tropiq already feels faster. The vector charts are buttery smooth, and the weather briefings actually make sense.",
    name: 'Mike Reeves',
    cert: 'PPL-IR',
    aircraft: 'Cessna 182',
  },
  {
    quote: "Finally, an EFB that works on my Samsung tablet. I was tired of buying iPads just for flying. The cross-platform sync is seamless — it just works.",
    name: 'Sarah Chen',
    cert: 'CPL',
    aircraft: 'Piper Cherokee',
  },
  {
    quote: "The weight and balance tool alone is worth the subscription. And the pricing is honest — no paywalls hiding features I need for actual flying.",
    name: 'David Okonkwo',
    cert: 'PPL',
    aircraft: 'Cirrus SR22',
  },
]

export function Testimonials() {
  const { ref, isInView } = useScrollAnimation()

  return (
    <section className="section-padding bg-white">
      <motion.div
        ref={ref}
        className="container mx-auto max-w-[1280px] px-8 lg:px-12"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <motion.div variants={fadeUp} transition={{ duration: 0.5 }} className="text-center mb-14">
          <h2 className="headline-section text-[var(--color-deep-slate)]">
            Pilots are already switching.
          </h2>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-6">
          {testimonials.map((t) => (
            <motion.div
              key={t.name}
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="relative p-7 rounded-xl bg-[var(--color-warm-white)] border border-slate-100"
            >
              {/* Quote mark */}
              <div className="absolute -top-3 left-6 text-4xl text-[var(--color-teal)]/30 font-serif leading-none">
                "
              </div>

              <p className="text-sm text-[var(--color-deep-slate)] leading-relaxed italic mb-5 pt-2">
                {t.quote}
              </p>

              <div className="flex items-center gap-3">
                {/* Avatar placeholder */}
                <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[var(--color-teal)]/20 to-[var(--color-sky)]/20 flex items-center justify-center">
                  <span className="text-xs font-semibold text-[var(--color-teal)]">
                    {t.name.split(' ').map(n => n[0]).join('')}
                  </span>
                </div>
                <div>
                  <p className="text-sm font-semibold text-[var(--color-deep-slate)]">{t.name}</p>
                  <p className="text-xs text-[var(--color-slate)]">
                    {t.cert} · {t.aircraft}
                  </p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </section>
  )
}
