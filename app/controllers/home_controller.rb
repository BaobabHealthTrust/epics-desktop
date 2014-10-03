class HomeController < ApplicationController
  def index
    @application = [
        ["Enter Transaction",'/product/select?task=data_entry',"search.png"],
        ["Stock Card",'/product/select?task=stock_card',"search.png"],
        ["Product Summary",'/product/search',"search.png"]
    ]


    @buttons_count = @application.length

    render :layout => false
  end

end
