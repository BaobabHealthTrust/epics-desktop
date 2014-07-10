class ProductController < ApplicationController
  def search
    render :layout => "touch_screen"
  end

  def select
    render :layout => "touch_screen"
  end

  def data_entry

    types = ['facility', 'Store room', 'Departments']
    location_type = EpicsLocationType.where("name in (?)", types).collect{|c| c.id}
    @receivers = EpicsLocation.where("epics_location_type_id in (?)",location_type).collect{|x| x.name}
    @receivers.delete(session[:location_name])
    @suppliers = EpicsSupplier.all.collect{|x| x.name}
    @product = EpicsProduct.find_by_name(params[:product])

  end

  def save_transaction

    if params[:record]['issued'].blank?

    else

    end

    render :text => true
  end

  def find_by_name_or_code
    @products = EpicsProduct.where("(product_code LIKE(?) OR
      name LIKE (?))", "%#{params[:search_str]}%",
                                   "%#{params[:search_str]}%").limit(100).map{|product|[[product.name]]}

    render :text => "<li></li><li>" + @products.join("</li><li>") + "</li>"
  end
end
