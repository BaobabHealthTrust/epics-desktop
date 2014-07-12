class HomeController < ApplicationController
  def index
    @application = [
        ["Enter Transaction",'/product/select',"search.png"],
        ["Stock Card",'/product/search',"search.png"]
    ]


    @buttons_count = @application.length

    render :layout => false
  end

end
