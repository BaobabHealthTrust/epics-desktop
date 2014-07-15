class StockDetailsController < ApplicationController
  def edit_current_quantity

    render :layout => "touch_screen"
  end

  def void

    product = EpicsProduct.find_by_name(params[:record]["item"])
    date = params[:record]['date'].to_date.strftime('%Y-%m-%d')
    if (params[:record]['isReceipt'].downcase == "true")

      stock = EpicsStockDetails.find_by_sql("SELECT epics_stock_details.* FROM epics_stock_details INNER JOIN epics_stocks s
                                      ON s.epics_stock_id = epics_stock_details.epics_stock_id
                                      WHERE s.invoice_number ='#{params[:record]['voucher']}' AND s.grn_date = '#{date}'
                                      AND epics_stock_details.batch_number = '#{params[:record]['batch']}'
                                      AND epics_stock_details.received_quantity = #{params[:record]['received']}
                                      AND epics_stock_details.epics_products_id = #{product.id}").first



      if stock.current_quantity.to_i ==  params[:record]['received'].to_i

        stock_expiry = stock.epics_stock_expiry_date

        stock_expiry.voided = 1
        stock_expiry.save

        stock.voided = 1
        stock.void_reason = "Wrongly captured"
        stock.voided_by = User.current.id
        stock.save

        result = "Record successfully voided"

      else

        result = "Some items were issued from this batch. Please void the issues first"

      end
    else

      product_order = EpicsProductOrders.find_by_sql("SELECT epics_product_orders.* FROM epics_product_orders INNER JOIN
                                                epics_stock_details s ON s.epics_stock_details_id = epics_product_orders.epics_stock_details_id
                                                WHERE s.batch_number = '#{params[:record]['batch']}' AND s.epics_products_id = #{product.id}
                                                AND epics_product_orders.quantity = #{params[:record]['issued']}
                                                AND DATE(epics_product_orders.created_at) = '#{date}'").first

      stock_details = product_order.epics_stock_details

      product_order.voided = 1
      if product_order.save
        stock_details.current_quantity += params[:record]['issued'].to_i
        stock_details.save
        result = "Record successfully voided"
      else
        result = "Record could not be voided"
      end
    end


    render :text => result
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
