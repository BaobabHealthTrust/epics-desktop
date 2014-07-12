class StockDetailsController < ApplicationController
  def edit_current_quantity

    render :layout => "touch_screen"
  end

  def void
  end

  def board_off_stock
    stock_id = params[:stock_id]
    reason = params[:reason]
    item_quantity = params[:stock_details][:item_quantity].to_i
    unless (params[:stock_details][:issue_quantity].to_i == 0)
      issue_quantity = params[:stock_details][:issue_quantity].to_i
    else
      issue_quantity = params[:stock_details][:other_quantity].to_i
    end
    board_off_quantity = issue_quantity * item_quantity

    stock = EpicsStockDetails.find(stock_id)

    if stock.current_quantity > 0
      if stock.current_quantity >= board_off_quantity
        ActiveRecord::Base.transaction do
          location_type = EpicsLocationType.find_by_name('Medication Disposal')
          epics_location = EpicsLocation.find_by_epics_location_type_id(location_type.id)
          order_type = EpicsOrderTypes.find_by_name('Board off')
          epics_order = EpicsOrders.new
          epics_order.epics_order_type_id = order_type.id
          epics_order.epics_location_id = epics_location.id
          epics_order.instructions = reason
          epics_order.save!

          product_order = EpicsProductOrders.new
          product_order.epics_order_id = epics_order.id
          product_order.epics_stock_details_id = stock.id
          product_order.quantity = board_off_quantity
          product_order.save!

          stock.current_quantity = (stock.current_quantity - board_off_quantity)
          stock.save
        end
      end
    end
    redirect_to :controller => "product", :action => "view", :product => session[:product]
  end

  def edit_stock_details
    stock_details = EpicsStockDetails.find(params[:stock_id])
    session[:epics_stock_details] = stock_details
    render :layout=> "touch_screen"
  end

  def save_edited_stock_details
    stock_details = session[:epics_stock_details]
    session[:epics_stock_details] = nil
    units = params[:units].delete_if{|value|value.blank? || value.match(/Other/i)}.to_s.to_i
    quantity = params[:quantity].to_i
    reason = params[:reason]
    received_quantity = units * quantity
    prev_stock = EpicsStockDetails.find(stock_details.id)
    prev_received_quantity = prev_stock.received_quantity
    difference = received_quantity - prev_received_quantity
    ActiveRecord::Base.transaction do
      old_stock = EpicsStockDetails.find(stock_details.id)
      old_stock.received_quantity = received_quantity
      old_stock.current_quantity = (old_stock.current_quantity) + difference
      old_stock.save!
      EpicsStockDetails.create!(
          :epics_stock_id => stock_details.epics_stock_id,
          :epics_products_id => stock_details.epics_products_id,
          :received_quantity => stock_details.received_quantity,
          :epics_product_units_id => stock_details.epics_product_units_id,
          :epics_location_id => stock_details.epics_location_id,
          :voided => 1,
          :voided_by => session[:user_id],
          :void_reason => reason
      )
    end
    redirect_to :controller => "product", :action => "view", :product => session[:product]
  end
end
