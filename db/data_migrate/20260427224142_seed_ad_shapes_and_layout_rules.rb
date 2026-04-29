class SeedAdShapesAndLayoutRules < ActiveRecord::Migration[8.1]
  SHAPES = [
    { name: "leaderboard", min_ratio: 3.5,  max_ratio: Float::INFINITY },
    { name: "landscape",   min_ratio: 1.15, max_ratio: 3.5 },
    { name: "square",      min_ratio: 0.85, max_ratio: 1.15 },
    { name: "portrait",    min_ratio: 0.65, max_ratio: 0.85 },
    { name: "story",       min_ratio: 0.45, max_ratio: 0.65 },
    { name: "skyscraper",  min_ratio: 0.0,  max_ratio: 0.45 },
  ].freeze

  PRIORITY = %w[headline cta wordmark logo subhead body decoration].freeze

  LAYOUT_RULES = {
    square: {
      wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.10 }, font_scale: 1.0,  align: "left" },
      headline:   { anchor: { x: 0.05, y: 0.16, w: 0.90, h: 0.25 }, font_scale: 1.0,  align: "center" },
      subhead:    { anchor: { x: 0.05, y: 0.42, w: 0.90, h: 0.18 }, font_scale: 0.9,  align: "center" },
      body:       { anchor: { x: 0.08, y: 0.60, w: 0.84, h: 0.18 }, font_scale: 0.85, align: "center" },
      cta:        { anchor: { x: 0.25, y: 0.80, w: 0.50, h: 0.12 }, font_scale: 0.9,  align: "center" },
      logo:       { anchor: { x: 0.35, y: 0.93, w: 0.30, h: 0.05 }, font_scale: 0.8,  align: "center" },
      decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
    },
    landscape: {
      wordmark:   { anchor: { x: 0.03, y: 0.05, w: 0.25, h: 0.15 }, font_scale: 1.0,  align: "left" },
      headline:   { anchor: { x: 0.03, y: 0.22, w: 0.55, h: 0.30 }, font_scale: 0.95, align: "left" },
      subhead:    { anchor: { x: 0.03, y: 0.54, w: 0.55, h: 0.18 }, font_scale: 0.85, align: "left" },
      body:       { anchor: { x: 0.03, y: 0.74, w: 0.55, h: 0.18 }, font_scale: 0.8,  align: "left" },
      cta:        { anchor: { x: 0.62, y: 0.60, w: 0.34, h: 0.15 }, font_scale: 0.9,  align: "center" },
      logo:       { anchor: { x: 0.62, y: 0.08, w: 0.34, h: 0.15 }, font_scale: 0.8,  align: "right" },
      decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
    },
    leaderboard: {
      wordmark:   { drop: true },
      headline:   { anchor: { x: 0.02, y: 0.10, w: 0.40, h: 0.80 }, font_scale: 0.75, align: "left" },
      subhead:    { drop: true },
      body:       { drop: true },
      cta:        { anchor: { x: 0.62, y: 0.15, w: 0.25, h: 0.70 }, font_scale: 0.7,  align: "center" },
      logo:       { anchor: { x: 0.89, y: 0.15, w: 0.10, h: 0.70 }, font_scale: 0.6,  align: "center" },
      decoration: { drop: true },
    },
    portrait: {
      wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.08 }, font_scale: 1.0,  align: "left" },
      headline:   { anchor: { x: 0.05, y: 0.14, w: 0.90, h: 0.20 }, font_scale: 1.0,  align: "center" },
      subhead:    { anchor: { x: 0.05, y: 0.36, w: 0.90, h: 0.13 }, font_scale: 0.9,  align: "center" },
      body:       { anchor: { x: 0.08, y: 0.51, w: 0.84, h: 0.20 }, font_scale: 0.85, align: "center" },
      cta:        { anchor: { x: 0.20, y: 0.74, w: 0.60, h: 0.10 }, font_scale: 0.9,  align: "center" },
      logo:       { anchor: { x: 0.30, y: 0.86, w: 0.40, h: 0.08 }, font_scale: 0.8,  align: "center" },
      decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
    },
    story: {
      wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.08 }, font_scale: 1.0,  align: "left" },
      headline:   { anchor: { x: 0.05, y: 0.16, w: 0.90, h: 0.20 }, font_scale: 1.1,  align: "center" },
      subhead:    { anchor: { x: 0.08, y: 0.38, w: 0.84, h: 0.12 }, font_scale: 0.9,  align: "center" },
      body:       { anchor: { x: 0.08, y: 0.52, w: 0.84, h: 0.18 }, font_scale: 0.85, align: "center" },
      cta:        { anchor: { x: 0.15, y: 0.75, w: 0.70, h: 0.10 }, font_scale: 1.0,  align: "center" },
      logo:       { anchor: { x: 0.30, y: 0.90, w: 0.40, h: 0.06 }, font_scale: 0.8,  align: "center" },
      decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
    },
    skyscraper: {
      wordmark:   { anchor: { x: 0.10, y: 0.03, w: 0.80, h: 0.08 }, font_scale: 0.7,  align: "center" },
      headline:   { anchor: { x: 0.05, y: 0.13, w: 0.90, h: 0.13 }, font_scale: 0.7,  align: "center" },
      subhead:    { anchor: { x: 0.05, y: 0.28, w: 0.90, h: 0.10 }, font_scale: 0.6,  align: "center" },
      body:       { drop: true },
      cta:        { anchor: { x: 0.08, y: 0.70, w: 0.84, h: 0.10 }, font_scale: 0.65, align: "center" },
      logo:       { anchor: { x: 0.15, y: 0.85, w: 0.70, h: 0.08 }, font_scale: 0.6,  align: "center" },
      decoration: { drop: true },
    },
  }.freeze

  def up
    SHAPES.each_with_index do |shape_data, idx|
      shape = AdShape.find_or_create_by!(name: shape_data[:name]) do |s|
        s.min_ratio = shape_data[:min_ratio]
        s.max_ratio = shape_data[:max_ratio]
        s.position = idx
      end

      rules = LAYOUT_RULES[shape_data[:name].to_sym] || {}
      rules.each do |role, config|
        AdShapeLayoutRule.find_or_create_by!(ad_shape: shape, role: role.to_s) do |r|
          if config[:drop]
            r.drop = true
            r.position = PRIORITY.index(role.to_s) || 99
          else
            r.anchor_x = config[:anchor][:x]
            r.anchor_y = config[:anchor][:y]
            r.anchor_w = config[:anchor][:w]
            r.anchor_h = config[:anchor][:h]
            r.font_scale = config[:font_scale]
            r.align = config[:align]
            r.drop = false
            r.position = PRIORITY.index(role.to_s) || 99
          end
        end
      end
    end
  end

  def down
    AdShapeLayoutRule.delete_all
    AdShape.delete_all
  end
end
