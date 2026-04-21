require "rails_helper"

RSpec.describe AdContinuation do
  describe ".collapse" do
    it "returns empty array for blank input" do
      expect(described_class.collapse(nil)).to eq([])
      expect(described_class.collapse([])).to eq([])
    end

    it "returns single text layers unchanged" do
      layers = [{ "id" => "1", "type" => "text", "content" => "Hello", "x" => 0, "y" => 0, "width" => 100, "height" => 20 }]
      result = described_class.collapse(layers)
      expect(result.length).to eq(1)
      expect(result.first["content"]).to eq("Hello")
    end

    it "preserves non-text layers" do
      layers = [
        { "id" => "img1", "type" => "image", "x" => 0, "y" => 0 },
        { "id" => "t1", "type" => "text", "content" => "Hi", "x" => 0, "y" => 0, "width" => 100, "height" => 20 }
      ]
      result = described_class.collapse(layers)
      expect(result.length).to eq(2)
      expect(result.map { |l| l["type"] }).to contain_exactly("text", "image")
    end

    it "collapses a two-layer continuation chain" do
      layers = [
        { "id" => "head", "type" => "text", "content" => "First line",
          "x" => 10, "y" => 10, "width" => 100, "height" => 20 },
        { "id" => "tail", "type" => "text", "content" => "second line",
          "continuation_of" => "head",
          "x" => 10, "y" => 35, "width" => 100, "height" => 20 }
      ]
      result = described_class.collapse(layers)
      text_layers = result.select { |l| l["type"] == "text" }
      expect(text_layers.length).to eq(1)
      expect(text_layers.first["content"]).to eq("First line second line")
      expect(text_layers.first["member_ids"]).to eq(%w[head tail])
    end

    it "computes union bounding box" do
      layers = [
        { "id" => "a", "type" => "text", "content" => "Top",
          "x" => 10, "y" => 5, "width" => 100, "height" => 20 },
        { "id" => "b", "type" => "text", "content" => "Bottom",
          "continuation_of" => "a",
          "x" => 5, "y" => 30, "width" => 120, "height" => 25 }
      ]
      result = described_class.collapse(layers)
      collapsed = result.find { |l| l["type"] == "text" }
      expect(collapsed["x"]).to eq(5.0)
      expect(collapsed["y"]).to eq(5.0)
      expect(collapsed["width"]).to eq(120.0)   # 125 - 5
      expect(collapsed["height"]).to eq(50.0)   # 55 - 5
    end

    it "collapses a three-layer chain" do
      layers = [
        { "id" => "1", "type" => "text", "content" => "A",
          "x" => 0, "y" => 0, "width" => 100, "height" => 10 },
        { "id" => "2", "type" => "text", "content" => "B", "continuation_of" => "1",
          "x" => 0, "y" => 15, "width" => 100, "height" => 10 },
        { "id" => "3", "type" => "text", "content" => "C", "continuation_of" => "2",
          "x" => 0, "y" => 30, "width" => 100, "height" => 10 }
      ]
      result = described_class.collapse(layers)
      text_layers = result.select { |l| l["type"] == "text" }
      expect(text_layers.length).to eq(1)
      expect(text_layers.first["content"]).to eq("A B C")
      expect(text_layers.first["member_ids"]).to eq(%w[1 2 3])
    end

    it "handles multiple independent chains" do
      layers = [
        { "id" => "h1", "type" => "text", "content" => "Chain1 Head",
          "x" => 0, "y" => 0, "width" => 100, "height" => 10 },
        { "id" => "t1", "type" => "text", "content" => "Chain1 Tail", "continuation_of" => "h1",
          "x" => 0, "y" => 15, "width" => 100, "height" => 10 },
        { "id" => "h2", "type" => "text", "content" => "Chain2 Head",
          "x" => 200, "y" => 0, "width" => 100, "height" => 10 },
        { "id" => "t2", "type" => "text", "content" => "Chain2 Tail", "continuation_of" => "h2",
          "x" => 200, "y" => 15, "width" => 100, "height" => 10 }
      ]
      result = described_class.collapse(layers)
      text_layers = result.select { |l| l["type"] == "text" }
      expect(text_layers.length).to eq(2)
      expect(text_layers.map { |l| l["content"] }).to contain_exactly(
        "Chain1 Head Chain1 Tail",
        "Chain2 Head Chain2 Tail"
      )
    end

    it "handles cycle protection (runaway guard)" do
      layers = [
        { "id" => "a", "type" => "text", "content" => "A", "continuation_of" => "b",
          "x" => 0, "y" => 0, "width" => 100, "height" => 10 },
        { "id" => "b", "type" => "text", "content" => "B", "continuation_of" => "a",
          "x" => 0, "y" => 15, "width" => 100, "height" => 10 }
      ]
      # Should not infinite loop
      result = described_class.collapse(layers)
      expect(result).to be_an(Array)
    end

    it "strips empty content when joining" do
      layers = [
        { "id" => "a", "type" => "text", "content" => "Hello",
          "x" => 0, "y" => 0, "width" => 100, "height" => 10 },
        { "id" => "b", "type" => "text", "content" => "  ", "continuation_of" => "a",
          "x" => 0, "y" => 15, "width" => 100, "height" => 10 }
      ]
      result = described_class.collapse(layers)
      expect(result.first["content"]).to eq("Hello")
    end

    it "is idempotent (already-collapsed input)" do
      layers = [
        { "id" => "solo", "type" => "text", "content" => "Standalone",
          "x" => 0, "y" => 0, "width" => 100, "height" => 10 }
      ]
      result1 = described_class.collapse(layers)
      result2 = described_class.collapse(result1)
      expect(result2).to eq(result1)
    end
  end
end
