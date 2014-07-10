require 'test_helper'

class StockDetailsControllerControllerTest < ActionController::TestCase
  test "should get void" do
    get :void
    assert_response :success
  end

end
