# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "digest"

module TokenReel
  class Generator
    def initialize(config)
      @config = config.validate!
      @timeline = Timeline.new(config)
      @renderer = Renderer.new(config, @timeline)
    end

    # Returns the output path on success.
    def generate!
      workdir = @config.keep_frames ? make_persistent_workdir : nil
      Dir.mktmpdir do |tmp|
        dir = workdir || tmp
        frames = sample_and_render(dir)
        GifWriter.assemble(frames, @config.out, @config.loop_count)
      end
      @config.out
    end

    private

    def make_persistent_workdir
      base = File.basename(@config.out.to_s).sub(/\.gif\z/i, "")
      base = "token_reel" if base.strip.empty?
      dir = "#{base}_frames"
      FileUtils.mkdir_p(dir)
      dir
    end

    # Walks the timeline at a fixed frame rate. Consecutive samples
    # that render to an identical frame (very common during the
    # "thinking" pause, or whenever fps > tps) are collapsed into one
    # frame with a longer delay instead of being rendered twice.
    def sample_and_render(dir)
      step = 1.0 / @config.fps
      delay_cs = [(step * 100).round, 1].max
      rendered = {} # signature -> path, so repeated (non-consecutive) states reuse a PNG

      frames = []
      t = 0.0
      index = 0
      loop do
        state = @timeline.state_at(t)
        sig = state.signature

        if frames.any? && frames.last[:sig] == sig
          frames.last[:delay_cs] += delay_cs
        else
          path = rendered[sig] ||= begin
            p = File.join(dir, format("frame_%05d.png", index += 1))
            @renderer.render(state, p)
            p
          end
          frames << { sig: sig, path: path, delay_cs: delay_cs }
        end

        break if t >= @timeline.duration

        t = [t + step, @timeline.duration].min
      end

      frames
    end
  end
end
