# frozen_string_literal: true

class Admin::AdShapeLayoutRulesController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AdShapeLayoutRule --namespace='admin' --smart-layout --gd --nested='ad_shape' --no-nav-menu

  helper :hot_glue
  include HotGlue::ControllerHelper

  before_action :ad_shape
  before_action :load_ad_shape_layout_rule, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }

  def ad_shape
    @ad_shape ||= AdShape.find(params[:ad_shape_id])
  end

  def load_ad_shape_layout_rule
    @ad_shape_layout_rule = ad_shape.ad_shape_layout_rules.find(params[:id])
  end

  def load_all_ad_shape_layout_rules
    @ad_shape_layout_rules = ad_shape.ad_shape_layout_rules.ordered
    @pagy, @ad_shape_layout_rules = pagy(@ad_shape_layout_rules)
  end

  def index
    load_all_ad_shape_layout_rules
  end

  def new
    @ad_shape_layout_rule = AdShapeLayoutRule.new(ad_shape: ad_shape)
    @action = "new"
  end

  def create
    flash[:notice] = +""
    modified_params = modify_date_inputs_on_params(ad_shape_layout_rule_params.dup, nil, {})
    modified_params = modified_params.merge(ad_shape: ad_shape)

    @ad_shape_layout_rule = AdShapeLayoutRule.new(modified_params)

    if @ad_shape_layout_rule.save
      flash[:notice] = "Successfully created #{@ad_shape_layout_rule.to_label}"
      ad_shape.reload
      load_all_ad_shape_layout_rules
      render :create
    else
      flash[:alert] = "Oops, your Layout Rule could not be created. #{@hawk_alarm}"
      @action = "new"
      render :create, status: :unprocessable_entity
    end
  end

  def show
    redirect_to edit_admin_ad_shape_ad_shape_layout_rule_path(@ad_shape, @ad_shape_layout_rule)
  end

  def edit
    @action = "edit"
    render :edit
  end

  def update
    flash[:notice] = +""
    flash[:alert] = nil

    modified_params = modify_date_inputs_on_params(update_ad_shape_layout_rule_params.dup, nil, {})

    @ad_shape_layout_rule.assign_attributes(modified_params)

    if @ad_shape_layout_rule.save
      ad_shape.reload
      flash[:notice] << "Saved #{@ad_shape_layout_rule.to_label}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "Layout Rule could not be saved. #{@hawk_alarm}"
      @action = "edit"
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @ad_shape_layout_rule.destroy!
      flash[:notice] = "Layout Rule successfully deleted"
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = "Layout Rule could not be deleted"
    end
    ad_shape.reload
    load_all_ad_shape_layout_rules
  end

  def ad_shape_layout_rule_params
    params.require(:ad_shape_layout_rule).permit(
      :role, :anchor_x, :anchor_y, :anchor_w, :anchor_h,
      :font_scale, :align, :drop, :position
    )
  end

  def update_ad_shape_layout_rule_params
    ad_shape_layout_rule_params
  end

  def namespace
    "admin/"
  end
end
