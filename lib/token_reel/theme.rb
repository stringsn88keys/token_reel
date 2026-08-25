# frozen_string_literal: true

module TokenReel
  module Theme
    PALETTES = {
      dark: {
        bg: "#0d1117", header: "#161b22", border: "#30363d",
        fg: "#c9d1d9", prompt: "#7ee787", muted: "#8b949e",
        dot_red: "#ff5f56", dot_yellow: "#ffbd2e", dot_green: "#27c93f"
      },
      matrix: {
        bg: "#000000", header: "#000000", border: "#003300",
        fg: "#00ff41", prompt: "#00ff41", muted: "#008f11",
        dot_red: "#003300", dot_yellow: "#005500", dot_green: "#00ff41"
      },
      light: {
        bg: "#ffffff", header: "#f0f0f0", border: "#d0d0d0",
        fg: "#24292f", prompt: "#116329", muted: "#6e7781",
        dot_red: "#ff5f56", dot_yellow: "#ffbd2e", dot_green: "#27c93f"
      },
      solarized: {
        bg: "#002b36", header: "#073642", border: "#586e75",
        fg: "#eee8d5", prompt: "#2aa198", muted: "#93a1a1",
        dot_red: "#dc322f", dot_yellow: "#b58900", dot_green: "#859900"
      }
    }.freeze

    def self.fetch(name)
      PALETTES.fetch(name.to_sym) do
        raise ConfigError, "unknown theme #{name.inspect} (valid: #{PALETTES.keys.join(', ')})"
      end
    end
  end
end
