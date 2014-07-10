class ProductController < ApplicationController
  def search
    render :layout => "touch_screen"
  end

  def select
    render :layout => "touch_screen"
  end

  def data_entry

    @product = EpicsProduct.find_by_name(params[:product])

  end

  def save_transaction

  end

  def find_by_name_or_code
    @products = EpicsProduct.where("(product_code LIKE(?) OR
      name LIKE (?))", "%#{params[:search_str]}%",
                                   "%#{params[:search_str]}%").limit(100).map{|product|[[product.name]]}

    render :text => "<li></li><li>" + @products.join("</li><li>") + "</li>"
  end
end
