class EpicsProduct < ActiveRecord::Base
	set_table_name :epics_products
  set_primary_key :epics_products_id
  #default_scope where("voided = 0")
  default_scope where("#{table_name}.voided = 0")
  belongs_to :epics_product_units, :foreign_key => :epics_product_units_id
  belongs_to :epics_product_type, :foreign_key => :epics_product_type_id
  belongs_to :epics_product_category, :foreign_key => :epics_product_category_id
  has_many :epics_stock_details,:class_name => 'EpicsStockDetails', 
    :foreign_key => :epics_products_id, :conditions => {:voided => 0}
  has_one :epics_item_cost,:class_name => 'EpicsItemCost', 
    :foreign_key => :epics_products_id, :conditions => {:voided => 0}

  include Epics

  def current_quantity(end_date = Date.today)
    EpicsStockDetails.joins("INNER JOIN epics_products p 
      ON epics_stock_details.epics_products_id = p.epics_products_id 
      AND p.epics_products_id = #{self.id}
      INNER JOIN epics_stocks s 
      ON s.epics_stock_id = epics_stock_details.epics_stock_id").where("
      s.grn_date <= ?", end_date).sum(:current_quantity)
  end

  def received_quantity(end_date = Date.today)
    stock_ids_which_are_not_receipts = [0]                                      
    (EpicsExchange.all || []).map do |e|                                        
      stock_ids_which_are_not_receipts << e.epics_stock_id                      
    end                                                                         
                                                                                
    (EpicsLendsOrBorrows.all || []).map do |l|                                  
      stock_ids_which_are_not_receipts << l.epics_stock_id                      
    end                                                                         
                                                                                
    received_quantity = EpicsStock.joins(:epics_stock_details).where("epics_products_id = ?         
    AND epics_stock_details.voided = 0 AND epics_stock_details.epics_stock_id NOT IN(?) 
    AND epics_stocks.grn_date <= ?", self.id,stock_ids_which_are_not_receipts.compact, 
    end_date).select("SUM(epics_stock_details.received_quantity) received_quantity")[0].received_quantity.to_f

    if (received_quantity.to_s[-2..-1]) == '.0'
      received_quantity = received_quantity.to_i
    end unless received_quantity.blank?

    return received_quantity
  end

  def losses_quantity(end_date = Date.today)
    order_type = EpicsOrderTypes.find_by_name('Board Off')                      
                                                                                
    board_off = EpicsOrders.joins("INNER JOIN epics_product_orders p                        
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0          
    AND epics_orders.epics_order_type_id = #{order_type.id}                     
    INNER JOIN epics_stock_details s                                            
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0     
    AND s.epics_products_id = #{self.id} INNER JOIN epics_stocks e              
    ON e.epics_stock_id = s.epics_stock_id AND e.voided = 0").select("SUM(p.quantity) 
    board_off").where("epics_orders.created_at <= ?",                
    end_date.strftime('%Y-%m-%d 23:59:59'))[0].board_off.to_f

    if (board_off.to_s[-2..-1]) == '.0'
      board_off = board_off.to_i
    end unless board_off.blank?

    return board_off
  end

  def positive_adjustments(end_date = Date.today)
    stock_ids_which_are_not_receipts = [0]                                      
    (EpicsExchange.all || []).map do |e|                                        
      stock_ids_which_are_not_receipts << e.epics_stock_id                      
    end                                                                         
                                                                                
    (EpicsLendsOrBorrows.all || []).map do |l|                                  
      stock_ids_which_are_not_receipts << l.epics_stock_id                      
    end                                                                         
                                                                                
    positive_adjustments = EpicsStock.joins("INNER JOIN epics_stock_details s                          
    ON s.epics_stock_id = epics_stocks.epics_stock_id AND s.voided = 0          
    AND s.epics_products_id = #{self.id}                                        
    AND s.epics_stock_id IN(#{stock_ids_which_are_not_receipts.compact.join(',')})
    LEFT JOIN epics_exchanges x ON x.epics_stock_id = s.epics_stock_id          
    AND x.voided = 0 LEFT JOIN epics_lends_or_borrows b ON b.epics_stock_id = s.epics_stock_id 
    AND b.voided = 0").select("SUM(s.received_quantity) positive_adjustments").where("epics_stocks.grn_date <= ?" ,
    end_date)[0].positive_adjustments.to_f 

    if (positive_adjustments.to_s[-2..-1]) == '.0'
      positive_adjustments = positive_adjustments.to_i
    end unless positive_adjustments.blank?

    return positive_adjustments
  end

  def negative_adjustments(end_date = Date.today)
    order_type = EpicsOrderTypes.where("name IN('Lend','Exchange')").map(&:epics_order_type_id)
                                                                                
    negative_adjustments = EpicsOrders.joins("INNER JOIN epics_product_orders p                        
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0          
    AND epics_orders.epics_order_type_id IN(#{order_type.join(',')})            
    INNER JOIN epics_stock_details s                                            
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0     
    AND s.epics_products_id = #{self.id} INNER JOIN epics_stocks e              
    ON e.epics_stock_id = s.epics_stock_id AND e.voided = 0").select("SUM(p.quantity) 
    negative_adjustments").where("epics_orders.created_at <= ?", 
    end_date.strftime('%Y-%m-%d 23:59:59'))[0].negative_adjustments.to_f 


    if (negative_adjustments.to_s[-2..-1]) == '.0'
      negative_adjustments = negative_adjustments.to_i
    end unless negative_adjustments.blank?

    return negative_adjustments
  end

  def issued(end_date = Date.today)
    type = EpicsOrderTypes.where("name IN (?)", ['Dispense', 'Donate']).collect{|x| x.id}

    issued = EpicsOrders.joins("INNER JOIN epics_product_orders o
      ON o.epics_order_id = epics_orders.epics_order_id
      AND epics_orders.epics_order_type_id IN(#{type.join(',')})
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND s.epics_products_id=#{self.id} INNER JOIN epics_stocks e 
      ON e.epics_stock_id = s.epics_stock_id").where("e.grn_date <= ?", end_date).sum(:quantity)
   
    return 0 if issued == '0' 
    return issued
  end

  def days_stocked_out(end_date = Date.today)
    stocked_out = EpicsStockDetails.joins("INNER JOIN epics_stocks s 
      ON s.epics_stock_id = epics_stock_details.epics_stock_id").where("epics_products_id = ? 
      AND s.grn_date <=?", self.id, end_date).select("epics_stock_details.updated_at last_update, 
      SUM(current_quantity) curr_quantity").having("curr_quantity <= 0").order("last_update DESC").map(&:last_update)

    unless stocked_out.blank?
      days = EpicsStockDetails.select("DATEDIFF(DATE('#{end_date}'),DATE('#{stocked_out.last.to_date}')) AS days_gone")[0]
      return days[:days_gone].to_i
    else
      return 'N/A'
    end
  end

  def unit
    self.epics_product_units.name
  end

  def category
    self.epics_product_category.name
  end

  def type
    self.epics_product_type.name
  end
end
