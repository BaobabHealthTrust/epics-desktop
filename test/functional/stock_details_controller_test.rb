require 'test_helper'

class StockDetailsControllerTest < ActionController::TestCase
  test "should get edit_current_quantity" do
    get :edit_current_quantity
    assert_response :success
  end

  test "should get void" do
    get :void
    assert_response :success
  end

end
