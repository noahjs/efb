import { motion } from 'framer-motion'
import { Map, Cloud, Navigation, BookOpen, Smartphone, Radio } from 'lucide-react'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'

const features = [
  {
    icon: Map,
    title: 'Maps',
    description: 'Vector charts at 60fps. Silky smooth pan and zoom with day/night modes and dynamic decluttering.',
  },
  {
    icon: Cloud,
    title: 'Weather',
    description: 'Real-time radar, winds aloft, and plain-English briefings organized by flight phase.',
  },
  {
    icon: Navigation,
    title: 'Flight Planning',
    description: 'Route optimization, weight & balance, fuel planning, and performance profiles for your aircraft.',
  },
  {
    icon: BookOpen,
    title: 'Logbook',
    description: 'Automatic flight recording with cross-device sync. Import your existing logbook in minutes.',
  },
  {
    icon: Smartphone,
    title: 'Cross-Platform',
    description: 'Full feature parity on iOS and Android. Your data syncs everywhere.',
  },
  {
    icon: Radio,
    title: 'Avionics Integration',
    description: 'Connect to Dynon, GRT, Garmin, and ADS-B receivers. Not just Stratus.',
  },
]

export function Features() {
  const { ref, isInView } = useScrollAnimation()

  return (
    <section id="features" className="section-padding bg-white">
      <div className="container mx-auto max-w-[1280px] px-8 lg:px-12">
        <motion.div
          ref={ref}
          variants={staggerContainer}
          initial="hidden"
          animate={isInView ? 'visible' : 'hidden'}
        >
          <motion.div variants={fadeUp} transition={{ duration: 0.5 }} className="text-center mb-14">
            <h2 className="headline-section text-[var(--color-deep-slate)]">
              Built for how you actually fly.
            </h2>
            <p className="text-body text-[var(--color-slate)] mt-4 max-w-2xl mx-auto">
              Every feature designed around the way pilots really plan, brief, and fly — not how software companies think you should.
            </p>
          </motion.div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-7">
            {features.map((feature) => {
              const Icon = feature.icon
              return (
                <motion.div
                  key={feature.title}
                  variants={fadeUp}
                  transition={{ duration: 0.5 }}
                  className="group p-7 rounded-xl border border-slate-200 bg-white hover:-translate-y-0.5 hover:shadow-lg hover:shadow-slate-200/50 transition-all duration-200 cursor-default"
                >
                  <div className="w-10 h-10 rounded-lg bg-[var(--color-teal)]/10 flex items-center justify-center mb-4">
                    <Icon size={20} className="text-[var(--color-teal)]" />
                  </div>
                  <h3 className="text-base font-semibold text-[var(--color-deep-slate)] mb-1.5">
                    {feature.title}
                  </h3>
                  <p className="text-sm text-[var(--color-slate)] leading-relaxed">
                    {feature.description}
                  </p>
                </motion.div>
              )
            })}
          </div>
        </motion.div>
      </div>
    </section>
  )
}
