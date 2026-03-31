class AdFont < ApplicationRecord
  belongs_to :ad

  has_one_attached :font_file

  validates :font_name, presence: true

  def measure_text_width(text, font_size)
    ttf = load_ttf
    return nil unless ttf

    cmap = ttf.cmap.unicode.first
    return nil unless cmap

    units_per_em = ttf.header.units_per_em
    total_width = 0

    text.each_char do |char|
      glyph_id = cmap[char.ord]
      if glyph_id && glyph_id > 0
        advance = ttf.horizontal_metrics.for(glyph_id).advance_width
        total_width += advance
      else
        # Fallback: use space width or half em for unknown glyphs
        space_id = cmap[" ".ord]
        if space_id && space_id > 0
          total_width += ttf.horizontal_metrics.for(space_id).advance_width
        else
          total_width += units_per_em * 0.5
        end
      end
    end

    (total_width.to_f / units_per_em * font_size).round(2)
  end

  def word_wrap(text, font_size, max_width)
    words = text.split(/\s+/)
    return [text] if words.size <= 1

    lines = []
    current_line = []
    space_width = measure_text_width(" ", font_size) || (font_size * 0.25)

    words.each do |word|
      word_width = measure_text_width(word, font_size)
      return [text] unless word_width # bail if measurement fails

      current_width = if current_line.empty?
        0
      else
        measure_text_width(current_line.join(" "), font_size) + space_width
      end

      if current_line.empty? || (current_width + word_width) <= max_width
        current_line << word
      else
        lines << current_line.join(" ")
        current_line = [word]
      end
    end

    lines << current_line.join(" ") if current_line.any?
    lines
  end

  private

  def load_ttf
    return nil unless font_file.attached?

    @ttf ||= begin
      data = font_file.download
      TTFunk::File.new(data)
    rescue => e
      Rails.logger.error("AdFont#load_ttf failed for #{font_name}: #{e.message}")
      nil
    end
  end
end
