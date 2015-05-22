module ApplicationHelper
  def version

    style = "style='background-color:red;'" unless session[:datetime].blank?
    "ePICS Version: #{APP_VERSION} - <span #{style}>#{(session[:datetime].to_date rescue Date.today).strftime('%A, %d-%b-%Y')}</span>"
  end

  def welcome_message
    "Muli bwanji, enter your user information or scan your id card. <span style='font-size:0.6em;float:righti;margin-right: 20px;'>(#{version})</span>".html_safe
  end
end
