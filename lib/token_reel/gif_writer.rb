# frozen_string_literal: true

require "open3"

module TokenReel
  module GifWriter
    # frames: [{ path: "...", delay_cs: Integer }, ...] in playback order.
    def self.assemble(frames, out_path, loop_count)
      raise RenderError, "no frames to assemble" if frames.empty?

      argv = [Renderer.convert_binary, "-loop", loop_count.to_s]
      frames.each do |f|
        argv += ["-delay", f[:delay_cs].to_s, "-dispose", "Background", f[:path]]
      end
      argv << out_path

      _out, err, status = Open3.capture3(*argv)
      raise RenderError, "ImageMagick failed to assemble GIF: #{err}" unless status.success?

      out_path
    end
  end
end
