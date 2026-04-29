class Api::AdShapesController < Api::BaseController
  def index
    shapes = AdShape.ordered.includes(:ad_shape_layout_rules)

    render json: shapes.map { |shape|
      {
        id: shape.id,
        name: shape.name,
        min_ratio: shape.min_ratio,
        max_ratio: shape.max_ratio,
        layout_summary: shape.layout_summary
      }
    }
  end
end
