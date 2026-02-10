import { motion } from 'framer-motion'
import { Clock, ArrowRight } from 'lucide-react'
import { useScrollAnimation, fadeUp, staggerContainer } from '../../hooks/useAnimations'

const articles = [
  {
    title: 'Understanding METARs: A Visual Guide',
    readTime: '5 min read',
    category: 'Fundamentals',
  },
  {
    title: 'Decoding TAFs for Flight Planning',
    readTime: '7 min read',
    category: 'Planning',
  },
  {
    title: 'Thunderstorm Avoidance Strategies',
    readTime: '6 min read',
    category: 'Safety',
  },
]

export function WeatherPreview() {
  const { ref, isInView } = useScrollAnimation()

  return (
    <section id="weather" className="section-padding bg-white">
      <motion.div
        ref={ref}
        className="container mx-auto max-w-[1280px] px-8 lg:px-12"
        variants={staggerContainer}
        initial="hidden"
        animate={isInView ? 'visible' : 'hidden'}
      >
        <motion.div variants={fadeUp} transition={{ duration: 0.5 }} className="text-center mb-14">
          <h2 className="headline-section text-[var(--color-deep-slate)]">
            Weather in Plain English.
          </h2>
          <p className="text-body text-[var(--color-slate)] mt-4 max-w-2xl mx-auto">
            Because a good preflight shouldn't require a meteorology degree. Learn what matters for your next flight.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-6">
          {articles.map((article) => (
            <motion.a
              key={article.title}
              href="#"
              variants={fadeUp}
              transition={{ duration: 0.5 }}
              className="group block rounded-xl border border-slate-200 overflow-hidden hover:-translate-y-0.5 hover:shadow-lg hover:shadow-slate-200/50 transition-all duration-200"
            >
              {/* Thumbnail placeholder */}
              <div className="h-36 bg-gradient-to-br from-[var(--color-navy)] to-[#152642] flex items-center justify-center relative overflow-hidden">
                {/* Simulated weather radar */}
                <div className="absolute w-24 h-24 rounded-full bg-[var(--color-teal)]/10 blur-xl" />
                <div className="absolute w-16 h-16 rounded-full bg-[var(--color-ifr)]/15 blur-lg top-8 right-12" />
                <span className="relative font-mono text-[11px] text-white/40 uppercase tracking-widest">
                  {article.category}
                </span>
              </div>

              <div className="p-5">
                <h3 className="text-sm font-semibold text-[var(--color-deep-slate)] group-hover:text-[var(--color-teal)] transition-colors mb-2.5 leading-snug">
                  {article.title}
                </h3>
                <div className="flex items-center justify-between">
                  <span className="flex items-center gap-1.5 text-xs text-[var(--color-slate)]">
                    <Clock size={13} />
                    {article.readTime}
                  </span>
                  <ArrowRight size={14} className="text-[var(--color-teal)] opacity-0 group-hover:opacity-100 transition-opacity" />
                </div>
              </div>
            </motion.a>
          ))}
        </div>
      </motion.div>
    </section>
  )
}
