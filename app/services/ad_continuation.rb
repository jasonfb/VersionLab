module AdContinuation
  module_function

  # Collapse continuation chains in a layers array.
  #
  # A chain is a linear sequence of text layers where each subsequent layer
  # has `continuation_of` set to the id of the previous layer. Collapsing
  # produces a single "head" layer with:
  #   - content   : joined text of all parts (space-separated)
  #   - x/y/w/h   : union bounding box of all parts
  #   - member_ids: ordered ids of all parts (head + children)
  #
  # Idempotent: if `continuation_of` references have already been resolved
  # (i.e. children are not present in the array), the input is returned
  # unchanged.
  def collapse(layers)
    return [] if layers.blank?

    by_id = layers.index_by { |l| l["id"] }
    chains = {}
    non_text = []

    layers.each do |layer|
      if layer["type"] == "text"
        head_id = chain_head_id(layer, by_id)
        (chains[head_id] ||= []) << layer
      else
        non_text << layer
      end
    end

    # Order chains by the position of the head in the original array
    head_order = layers.each_with_index.each_with_object({}) { |(l, i), h| h[l["id"]] ||= i }
    ordered_heads = chains.keys.sort_by { |hid| head_order[hid] || Float::INFINITY }

    collapsed_text = ordered_heads.map { |hid| collapse_chain(chains[hid]) }
    collapsed_text + non_text
  end

  def chain_head_id(layer, by_id, depth = 0)
    return layer["id"] if depth > 32 # cycle / runaway guard

    parent_id = layer["continuation_of"]
    return layer["id"] if parent_id.blank?

    parent = by_id[parent_id]
    return layer["id"] unless parent && parent["type"] == "text"

    chain_head_id(parent, by_id, depth + 1)
  end

  def collapse_chain(parts)
    return parts.first if parts.size == 1

    # Sort parts by document position via continuation_of links so the head
    # comes first regardless of input order.
    sorted = sort_chain(parts)
    head = sorted.first.dup

    contents = sorted.map { |p| p["content"].to_s.strip }.reject(&:empty?)
    head["content"] = contents.join(" ")
    head["member_ids"] = sorted.map { |p| p["id"] }

    xs = sorted.map { |p| p["x"].to_f }
    ys = sorted.map { |p| p["y"].to_f }
    rights = sorted.map { |p| p["x"].to_f + p["width"].to_f }
    bottoms = sorted.map { |p| p["y"].to_f + p["height"].to_f }

    head["x"] = xs.min
    head["y"] = ys.min
    head["width"] = (rights.max - xs.min)
    head["height"] = (bottoms.max - ys.min)

    head
  end

  # Order parts so head (no continuation_of) comes first, then each successor
  # in the linked-list order.
  def sort_chain(parts)
    by_id = parts.index_by { |p| p["id"] }
    head = parts.find { |p| p["continuation_of"].blank? || !by_id.key?(p["continuation_of"]) }
    return parts unless head

    ordered = [head]
    children_by_parent = parts.group_by { |p| p["continuation_of"] }
    current = head
    while (next_parts = children_by_parent[current["id"]])
      next_part = next_parts.first
      break if ordered.include?(next_part)
      ordered << next_part
      current = next_part
    end
    ordered
  end
end
