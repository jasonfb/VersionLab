require "rails_helper"

RSpec.describe AdLayout::LayoutTemplate do
  describe ".for_bucket" do
    AdLayout::AspectRatioBucket.all_buckets.each do |bucket|
      it "returns a template for #{bucket}" do
        template = described_class.for_bucket(bucket)
        expect(template).to be_a(Hash)
        expect(template).to have_key(:headline)
        expect(template).to have_key(:cta)
      end
    end

    it "raises for unknown bucket" do
      expect { described_class.for_bucket(:widescreen) }.to raise_error(ArgumentError, /Unknown bucket/)
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
    AdLayout::LayoutTemplate::TEMPLATES.each do |bucket, template|
      context "#{bucket} template" do
        it "has valid anchor percentages for all placed roles" do
          template.each do |role, entry|
            next if entry[:drop]

            anchor = entry[:anchor]
            expect(anchor[:x]).to be_between(0.0, 1.0), "#{bucket}.#{role} anchor.x out of range"
            expect(anchor[:y]).to be_between(0.0, 1.0), "#{bucket}.#{role} anchor.y out of range"
            expect(anchor[:w]).to be_between(0.0, 1.0), "#{bucket}.#{role} anchor.w out of range"
            expect(anchor[:h]).to be_between(0.0, 1.0), "#{bucket}.#{role} anchor.h out of range"
            expect(anchor[:x] + anchor[:w]).to be <= 1.01, "#{bucket}.#{role} exceeds canvas width"
            expect(anchor[:y] + anchor[:h]).to be <= 1.01, "#{bucket}.#{role} exceeds canvas height"
          end
        end

        it "has a positive font_scale for all placed roles" do
          template.each do |role, entry|
            next if entry[:drop]
            expect(entry[:font_scale]).to be > 0, "#{bucket}.#{role} font_scale must be positive"
          end
        end
      end
    end
  end
end
