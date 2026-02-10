import { Navbar } from './components/Navbar'
import { Hero } from './components/sections/Hero'
import { SocialProof } from './components/sections/SocialProof'
import { Features } from './components/sections/Features'
import { CrossPlatform } from './components/sections/CrossPlatform'
import { WeatherPreview } from './components/sections/WeatherPreview'
import { Pricing } from './components/sections/Pricing'
import { Testimonials } from './components/sections/Testimonials'
import { FinalCTA } from './components/sections/FinalCTA'
import { Footer } from './components/Footer'

function App() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <SocialProof />
        <Features />
        <CrossPlatform />
        <WeatherPreview />
        <Pricing />
        <Testimonials />
        <FinalCTA />
      </main>
      <Footer />
    </>
  )
}

export default App
