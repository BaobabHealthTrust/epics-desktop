class ProductController < ApplicationController
  def search
    render :layout => "touch_screen"
  end

  def select
    @action = params[:task] rescue "data entry"
    render :layout => "touch_screen"
  end

  def data_entry

    types = ['facility', 'Store room', 'Departments']
    facility_id = EpicsLocationType.find_by_name("facility").id
    location_type = EpicsLocationType.where("name in (?)", types).collect{|c| c.id}
    @receivers = EpicsLocation.where("epics_location_type_id in (?)",location_type).collect{|x| x.name}
    @facilities = EpicsLocation.where("epics_location_type_id = ?",facility_id).collect{|x| x.name}
    @receivers.delete(session[:location_name])
    @suppliers = EpicsSupplier.all.collect{|x| x.name}
    @product = EpicsProduct.find_by_name(params[:product])

  end

  def save_transaction

    created_at = "#{params[:record]['date'].to_date} #{Time.now.strftime('%H:%M:%S')}" rescue nil

    if (params[:record]['isReceipt'].downcase == "true")

      product = EpicsProduct.find_by_product_code(params[:record]['item'])

      supplier =  (params[:record]['transaction'] != "receipt") ? "Other" : params[:record]['interactor']

      EpicsStock.transaction do
        stock = EpicsStock.new()
        stock.grn_date = params[:record]['date']
        stock.invoice_number = params[:record]['voucher']
        stock.epics_supplier_id = EpicsSupplier.find_by_name(supplier).id
        stock.save!

        witness = EpicsWitnessNames.new
        witness.epics_stock_id = stock.epics_stock_id
        witness.name = "Administrator"
        witness.save!

        stock_detail = EpicsStockDetails.new()
        stock_detail.epics_stock_id = stock.epics_stock_id
        stock_detail.epics_products_id = product.id
        stock_detail.epics_location_id = session[:location_id]
        stock_detail.received_quantity = params[:record]['received']
        stock_detail.current_quantity = params[:record]['received']
        stock_detail.batch_number = params[:record]['batch']
        stock_detail.epics_product_units_id = product.epics_product_units_id
        stock_detail.save!

        stock_expiry_dates = EpicsStockExpiryDates.new()
        stock_expiry_dates.epics_stock_details_id = stock_detail.epics_stock_details_id
        stock_expiry_dates.expiry_date = params[:record]['date'].to_date + 1.year
        stock_expiry_dates.save!

      end

      result = "Record Saved Successfully"

    else

      stock = EpicsStockDetails.find(:first,:conditions =>["batch_number = ? and current_quantity >= ?",
                                                           params[:record]['batch'],params[:record]['issued']])

      if (stock.blank?)
        result = "Insufficient quantity to issue"
      else

        order_type = EpicsOrderTypes.find_by_name(params[:record]["transaction"])

        EpicsOrders.transaction do
          order = EpicsOrders.new()
          order.epics_order_type_id = order_type.id
          order.epics_location_id = EpicsLocation.find_by_name(params[:record]['interactor']).id
          order.created_at = created_at
          order.save

          item_order = EpicsProductOrders.new()
          item_order.epics_order_id = order.id
          item_order.epics_stock_details_id = stock.id
          item_order.quantity = params[:record]['issued']
          item_order.created_at = "#{order.created_at.to_date} #{Time.now.strftime('%H:%M:%S')}"
          item_order.save

          stock.current_quantity = (stock.current_quantity - params[:record]['issued'].to_i)
          stock.save
        end

        result = "Record Saved Successfully"
      end

    end

    render :text => result
  end

  def find_by_name_or_code
    @products = EpicsProduct.where("(product_code LIKE(?) OR
      name LIKE (?))", "%#{params[:search_str]}%",
                                   "%#{params[:search_str]}%").limit(100).map{|product|[[product.name]]}

    render :text => "<li></li><li>" + @products.join("</li><li>") + "</li>"
  end
  def view
    @product = EpicsProduct.where("name = ?",params[:product])[0]
    if @product.blank?
      redirect_to "/"
    else
      session[:product] = params[:product]
      render :layout => "custom"
    end
  end
  def stock_card
    @item = EpicsProduct.find_by_name(params[:product])
    @page_title = "#{@item.name}<br />Stock Card"
    @trail = {}

    EpicsReport.receipts(@item, @trail)
    EpicsReport.issues(@item, @trail)
    EpicsReport.negative_adjustments(@item, @trail)
    EpicsReport.positive_adjustments(@item, @trail)
    EpicsReport.losses(@item, @trail)

  end
end
