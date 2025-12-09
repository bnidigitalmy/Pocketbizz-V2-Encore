import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./styles/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#eef8ff",
          100: "#d8ecff",
          200: "#b6dbff",
          300: "#84c3ff",
          400: "#4da4ff",
          500: "#1f85f0",
          600: "#0f68c8",
          700: "#0f57a5",
          800: "#114a87",
          900: "#123f70",
        },
        accent: {
          100: "#fff3e6",
          500: "#f9a826",
          600: "#d9881b",
        },
        success: "#16a34a",
        warning: "#f59e0b",
        muted: "#4b5563",
      },
      boxShadow: {
        card: "0 10px 40px rgba(0,0,0,0.08)",
      },
      fontFamily: {
        display: ["Inter", "ui-sans-serif", "system-ui", "sans-serif"],
        body: ["Inter", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      maxWidth: {
        "8xl": "96rem",
      },
      backgroundImage: {
        "grid-pattern":
          "radial-gradient(circle at 1px 1px, rgba(255,255,255,0.3) 1px, transparent 0)",
      },
    },
  },
  plugins: [],
};

export default config;

