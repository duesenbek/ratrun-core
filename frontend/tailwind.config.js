/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        mono: ['"Roboto Mono"', 'monospace'],
      },
      colors: {
        background: '#050505',
        card: '#111111',
        primary: '#B6FF00',
        text: '#EAEAEA',
        muted: '#555555',
      },
      boxShadow: {
        glow: '0 0 10px rgba(182, 255, 0, 0.2)',
      }
    },
  },
  plugins: [],
}
