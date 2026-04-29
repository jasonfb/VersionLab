require "rails_helper"

RSpec.describe AdLayout::LayoutTemplate do
  include_context "seeded ad shapes"

  describe ".for_shape" do
    AdLayout::AspectRatioBucket.all_shapes.each do |shape|
      it "returns a template for #{shape}" do
        template = described_class.for_shape(shape)
        expect(template).to be_a(Hash)
        expect(template).to have_key(:headline)
        expect(template).to have_key(:cta)
      end
    end

    it "raises for unknown shape" do
      expect { described_class.for_shape(:widescreen) }.to raise_error(ArgumentError, /Unknown shape/)
    end
  end

  describe ".for_role" do
    it "returns anchor and font_scale for a placed role" do
      entry = described_class.for_role(:square, :headline)
      expect(entry[:anchor]).to include(:x, :y, :w, :h)
      expect(entry[:font_scale]).to be_a(Numeric)
      expect(entry[:align]).to be_present
    end

    it "returns drop: true for a dropped role" do
      entry = described_class.for_role(:leaderboard, :body)
      expect(entry[:drop]).to be true
    end

    it "returns nil for undefined role" do
      expect(described_class.for_role(:square, :nonexistent)).to be_nil
    end
  end

  describe ".placed_roles" do
    it "returns roles in priority order excluding dropped ones" do
      placed = described_class.placed_roles(:square)
      expect(placed).to include("headline", "cta", "subhead", "body")
      expect(placed.index("headline")).to be < placed.index("body")
    end

    it "excludes dropped roles for leaderboard" do
      placed = described_class.placed_roles(:leaderboard)
      expect(placed).to include("headline", "cta", "logo")
      expect(placed).not_to include("subhead", "body", "decoration")
    end

    it "excludes dropped roles for skyscraper" do
      placed = described_class.placed_roles(:skyscraper)
      expect(placed).not_to include("body", "decoration")
    end
  end

  describe ".dropped_roles" do
    it "returns empty for square (nothing dropped)" do
      expect(described_class.dropped_roles(:square)).to be_empty
    end

    it "returns subhead, body, decoration for leaderboard" do
      dropped = described_class.dropped_roles(:leaderboard)
      expect(dropped).to contain_exactly("subhead", "body", "decoration")
    end
  end

  describe ".anchor_to_pixels" do
    it "converts percentage anchors to pixel coordinates" do
      anchor = { x: 0.05, y: 0.10, w: 0.90, h: 0.25 }
      pixels = described_class.anchor_to_pixels(anchor, 1080, 1080)

      expect(pixels[:x]).to eq(54)
      expect(pixels[:y]).to eq(108)
      expect(pixels[:w]).to eq(972)
      expect(pixels[:h]).to eq(270)
    end

    it "handles non-square dimensions" do
      anchor = { x: 0.02, y: 0.10, w: 0.40, h: 0.80 }
      pixels = described_class.anchor_to_pixels(anchor, 728, 90)

      expect(pixels[:x]).to eq(15)
      expect(pixels[:y]).to eq(9)
      expect(pixels[:w]).to eq(291)
      expect(pixels[:h]).to eq(72)
    end
  end

  describe "template structure validation" do
    AdShape.ordered.each do |shape_record|
      context "#{shape_record.name} template" do
        it "has valid anchor percentages for all placed roles" do
          shape_record.ad_shape_layout_rules.placed.each do |rule|
            expect(rule.anchor_x).to be_between(0.0, 1.0), "#{shape_record.name}.#{rule.role} anchor_x out of range"
            expect(rule.anchor_y).to be_between(0.0, 1.0), "#{shape_record.name}.#{rule.role} anchor_y out of range"
            expect(rule.anchor_w).to be_between(0.0, 1.0), "#{shape_record.name}.#{rule.role} anchor_w out of range"
            expect(rule.anchor_h).to be_between(0.0, 1.0), "#{shape_record.name}.#{rule.role} anchor_h out of range"
            expect(rule.anchor_x + rule.anchor_w).to be <= 1.01, "#{shape_record.name}.#{rule.role} exceeds canvas width"
            expect(rule.anchor_y + rule.anchor_h).to be <= 1.01, "#{shape_record.name}.#{rule.role} exceeds canvas height"
          end
        end

        it "has a positive font_scale for all placed roles" do
          shape_record.ad_shape_layout_rules.placed.each do |rule|
            expect(rule.font_scale).to be > 0, "#{shape_record.name}.#{rule.role} font_scale must be positive"
          end
        end
      end
    end
  end
end
