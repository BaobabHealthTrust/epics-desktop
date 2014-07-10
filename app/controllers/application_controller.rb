class ApplicationController < ActionController::Base
  #protect_from_forgery
  before_filter :perform_basic_auth, :set_issue_date, :except => ['login','logout','authenticate',
    'store_room_printable','drug_availability_printable','monthly_report_printable',
    'daily_dispensation_printable','disposed_items_printable','expired_items_printable',
    'stock_card_printable','items_to_expire_next_six_months_attachment',
    'items_to_expire_next_six_months_to_pdf','daily_dispensation_attachment',
    'daily_dispensation_to_pdf', 'received_items_attachment','received_items_to_pdf','send_email',
    'monthly_report_attachment','monthly_report_to_pdf'
  ]

  protected                                                                     
                                                                                
  def perform_basic_auth
    if session[:user_id].blank?
      respond_to do |format|                                                    
        format.html { redirect_to :controller => 'user',:action => 'logout' }   
      end                                                                       
    elsif not session[:user_id].blank?
      User.current = User.find(session[:user_id])
    end                                                                         
  end 

  def set_issue_date
    unless session[:issue_date].blank?
      EpicsOrders.issue_date = session[:issue_date]
    end
  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
end

