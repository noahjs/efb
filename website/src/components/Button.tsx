import { type ReactNode } from 'react'

interface ButtonProps {
  children: ReactNode
  variant?: 'primary' | 'secondary'
  size?: 'md' | 'lg'
  href?: string
  onClick?: () => void
  className?: string
}

export function Button({ children, variant = 'primary', size = 'md', href, onClick, className = '' }: ButtonProps) {
  const base = 'inline-flex items-center justify-center font-semibold tracking-wide rounded-lg transition-all duration-200 cursor-pointer'

  const variants = {
    primary: 'bg-[var(--color-teal)] text-white hover:bg-[var(--color-teal-hover)] shadow-lg shadow-[var(--color-teal)]/20 hover:shadow-xl hover:shadow-[var(--color-teal)]/30 active:scale-[0.98]',
    secondary: 'bg-transparent text-white border-2 border-white/30 hover:border-white/60 hover:bg-white/5 active:scale-[0.98]',
  }

  const sizes = {
    md: 'px-5 py-2.5 text-sm',
    lg: 'px-7 py-3 text-[15px]',
  }

  const classes = `${base} ${variants[variant]} ${sizes[size]} ${className}`

  if (href) {
    return (
      <a href={href} className={classes}>
        {children}
      </a>
    )
  }

  return (
    <button onClick={onClick} className={classes}>
      {children}
    </button>
  )
}
