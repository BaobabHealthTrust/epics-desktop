class EpicsReport < ActiveRecord::Base


  def self.alerts
    alerts = Hash.new(0)                                                       
                                                                                
    alerts['Items expiring in the next 6 months'] += EpicsStockExpiryDates.joins("
      INNER JOIN epics_stock_details s ON s.epics_stock_id = epics_stock_expiry_dates.epics_stock_details_id
      INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id  
      AND p.expire = 1").where("DATEDIFF(expiry_date,CURRENT_DATE())            
      BETWEEN 1 AND 183 AND current_quantity > 0").count(:expiry_date)                                   
                                                                                
    alerts['Items below minimum stock'] += EpicsStockDetails.joins("           
      INNER JOIN epics_products p ON p.epics_products_id = epics_stock_details.epics_products_id
    ").group('epics_stock_details.epics_products_id').select("SUM(current_quantity) quantity,
      min_stock").having("quantity > 0 AND quantity < min_stock").length                        
                                                                                
    alerts['Out of stock items'] += EpicsStockDetails.joins("                  
      INNER JOIN epics_products p ON p.epics_products_id = epics_stock_details.epics_products_id
    ").group('p.epics_products_id').select("SUM(current_quantity) quantity,
      min_stock").having("quantity <= 0").length                                
                                             
    order_type = EpicsOrderTypes.find_by_name('Board Off')
                                   
    alerts['Missing items'] += EpicsOrders.joins("INNER JOIN epics_product_orders p                        
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0          
    AND epics_orders.epics_order_type_id = #{order_type.id}                     
    INNER JOIN epics_stock_details s                                            
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0     
    INNER JOIN epics_stocks e ON e.epics_stock_id = s.epics_stock_id 
    AND e.voided = 0 AND instructions = 'missing'").length 

    alerts['Expired items'] += EpicsStockExpiryDates.joins("
      INNER JOIN epics_stock_details s ON s.epics_stock_id = epics_stock_expiry_dates.epics_stock_details_id
      INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id  
      AND p.expire = 1").where("DATEDIFF(expiry_date,CURRENT_DATE()) <= 0         
      AND current_quantity > 0").count(:expiry_date)                                   

    return alerts
  end

  def self.monthly_report(end_date)
    @item_categories = {}
    EpicsProductCategory.all.each do |cat|
      (self.get_receipts_by_category_and_date(cat.id,end_date) || []).each do |receipt|
        if @item_categories[receipt[:grn_date]].blank?
          @item_categories[receipt[:grn_date]] = {}
        end
        
        if @item_categories[receipt[:grn_date]]["#{cat.name}: #{cat.description}"].blank?  
          @item_categories[receipt[:grn_date]]["#{cat.name}: #{cat.description}"] = {} 
        end
      
        if @item_categories[receipt[:grn_date]]["#{cat.name}: #{cat.description}"][receipt[:item_id]].blank?
          item = EpicsProduct.find(receipt[:item_id]) rescue []
          next if item.blank?
          @item_categories[receipt[:grn_date]]["#{cat.name}: #{cat.description}"][receipt[:item_id]] = {
            :item_code => receipt[:item_code],
            :item => receipt[:item_name],
            :unit_of_issue => receipt[:unit_of_issue],
            :current_quantity => item.current_quantity(end_date.to_date),
            :received_quantity => item.received_quantity(end_date.to_date),
            :losses => item.losses_quantity(end_date.to_date),
            :positive_adjustments => item.positive_adjustments(end_date.to_date),
            :negative_adjustments => item.negative_adjustments(end_date.to_date),
            :issued => item.issued(end_date.to_date),
            :days_stocked_out => item.days_stocked_out(end_date.to_date)
          }
        end 

      end
    end

    return @item_categories
  end

  def self.get_receipts_by_category_and_date(category_id, end_date)
    EpicsStock.joins("
      INNER JOIN epics_stock_details s ON epics_stocks.epics_stock_id = s.epics_stock_id 
      AND epics_stocks.grn_date <= '#{end_date}'
      INNER JOIN epics_products e ON s.epics_products_id = e.epics_products_id
      INNER JOIN epics_product_units u ON u.epics_product_units_id = e.epics_product_units_id
      AND e.epics_product_category_id = #{category_id}
    ").group("e.epics_products_id").select("
      epics_stocks.grn_date, e.epics_products_id , product_code, e.name product_name, u.name unit
    ").collect do |r| {
      :grn_date => r.grn_date, :item_id => r.epics_products_id.to_i , 
      :item_code => r.product_code, :item_name => r.product_name, 
      :unit_of_issue => r.unit } 
    end
  end

  def self.daily_dispensation(date = Date.today)
    type = EpicsOrderTypes.where("name IN (?)", ['Dispense', 'Donate']).collect{|x| x.id}
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    issued = EpicsOrders.joins("INNER JOIN epics_product_orders o
      ON o.epics_order_id = epics_orders.epics_order_id
      AND epics_orders.epics_order_type_id IN(#{type.join(',')})
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND o.created_at >= '#{start_date}' AND o.created_at <= '#{end_date}'
      INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id
      ").select("p.name pname,o.created_at dispensed_date,SUM(quantity) quantity,
        p.product_code item_code,s.epics_products_id item_id").group("s.epics_products_id")
    
    return issued.collect do |r|{
      :item_name => r.pname, :item_id => r.item_id,
      :item_code => r.item_code,:issue_date => r.dispensed_date, 
      :quantity_issued => r.quantity
      }
    end
  end

  def self.drug_daily_dispensation(item_id, date = Date.today)
    type = EpicsOrderTypes.where("name IN (?)", ['Dispense', 'Donate']).collect{|x| x.id}
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    issued = EpicsOrders.joins("INNER JOIN epics_product_orders o
      ON o.epics_order_id = epics_orders.epics_order_id
      AND epics_orders.epics_order_type_id IN(#{type.join(',')})
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND o.created_at >= '#{start_date}' AND o.created_at <= '#{end_date}'
      AND s.epics_products_id = #{item_id}
      INNER JOIN epics_locations l ON l.epics_location_id = s.epics_location_id
      INNER JOIN epics_locations i ON i.epics_location_id = epics_orders.epics_location_id
      INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id
      ").select("p.name pname,l.name lname,s.created_at dispensed_date,SUM(quantity) quantity,
        p.product_code item_code,i.name issued_to,s.epics_products_id item_id").group("s.epics_products_id,i.epics_location_id")
    
    return issued.collect do |r|{
      :item_name => r.pname, :issued_from => r.lname,:item_id => r.item_id,
      :item_code => r.item_code,:issue_date => r.dispensed_date, 
      :quantity_issued => r.quantity, :issued_to => r.issued_to
      }
    end
  end

  ############################### stock card ##############################################
   def self.current_quantity(stock, item, end_date = Date.today)
    EpicsStockDetails.joins("INNER JOIN epics_products p 
      ON epics_stock_details.epics_products_id = p.epics_products_id 
      AND p.epics_products_id = #{item.id}
      INNER JOIN epics_stocks s 
      ON s.epics_stock_id = epics_stock_details.epics_stock_id").where("
      s.grn_date <= ? AND s.epics_stock_id = ?", end_date,stock.id).sum(:current_quantity)
  end

  def self.received_quantity(stock, item, end_date = Date.today)
    EpicsStockDetails.joins("INNER JOIN epics_products p 
      ON epics_stock_details.epics_products_id = p.epics_products_id 
      AND p.epics_products_id = #{item.id}
      INNER JOIN epics_stocks s 
      ON s.epics_stock_id = epics_stock_details.epics_stock_id").where("
      s.grn_date <= ? AND s.epics_stock_id = ?", end_date,stock.id).sum(:received_quantity)
  end

  def self.losses_quantity(stock, item, end_date = Date.today)

    EpicsStockDetails.find_by_sql("SELECT SUM(current_quantity) count FROM
      epics_stock_details INNER JOIN epics_products p 
      ON epics_stock_details.epics_products_id = p.epics_products_id 
      AND p.epics_products_id = #{item.id}
      INNER JOIN epics_stocks s 
      ON s.epics_stock_id = epics_stock_details.epics_stock_id
      WHERE s.grn_date <= '#{end_date}' AND epics_stock_details.voided = 1 
      AND epics_stock_details.void_reason IN('damaged','missing','expired')
      AND s.epics_stock_id = #{stock.id}").first.count.to_i rescue 0
  end

  def self.positive_adjustments(stock, item, end_date = Date.today)
    type = EpicsLendsOrBorrowsType.where("name = ?",'Borrow')[0]

    borrowed = EpicsLendsOrBorrows.joins("INNER JOIN epics_stocks es
    ON es.epics_stock_id = epics_lends_or_borrows.epics_stock_id
    AND epics_lends_or_borrows.epics_lends_or_borrows_type_id = #{type.id}
    INNER JOIN epics_stock_details s ON s.epics_stock_id = es.epics_stock_id
    AND s.epics_products_id = #{item.id}").where("es.grn_date <= ?
    AND es.epics_stock_id = ?", end_date, stock.id).sum(:received_quantity)


    exchange = EpicsExchange.joins("INNER JOIN epics_product_orders o 
      ON o.epics_order_id=epics_exchanges.epics_order_id
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND s.epics_products_id = #{item.id} INNER JOIN epics_stocks e              
      ON e.epics_stock_id = s.epics_stock_id").where("e.grn_date <= ?
      AND e.epics_stock_id = ?",end_date,stock.id).sum(:received_quantity)
      
    receipts = EpicsStock.joins("INNER JOIN epics_stock_details s               
      ON s.epics_stock_id = epics_stocks.epics_stock_id                         
      AND s.epics_products_id = #{item.id}").where("epics_stocks.grn_date <= ?
      AND epics_stocks.epics_stock_id = ?",end_date,stock.id).sum(:received_quantity)                                         
                                                                                
    count = [exchange.to_f , borrowed.to_f].sum
    count = [count , (receipts.to_f - count)].sum
 
    if(count.to_s.split('.')[1] == '0')
      return count.to_i
    end
    return count
  end

  def self.negative_adjustments(stock, item, end_date = Date.today)
    type_ids = EpicsOrderTypes.where("name IN(?)",['Lend','Exchange','Return']).map(&:id)

    epics_lends = EpicsOrders.joins("INNER JOIN epics_product_orders o
      ON o.epics_order_id = epics_orders.epics_order_id
      AND epics_orders.epics_order_type_id IN(#{type_ids.join(',')})
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND s.epics_products_id=#{item.id} INNER JOIN epics_stocks e 
      ON e.epics_stock_id = s.epics_stock_id").where("e.grn_date <= ?
      AND e.epics_stock_id = ?" ,end_date,stock.id).sum(:quantity)
    
    return epics_lends
  end

  def self.issued(stock, item, end_date = Date.today)
    type = EpicsOrderTypes.where("name = ?",'Dispense')[0]

    issued = EpicsOrders.joins("INNER JOIN epics_product_orders o
      ON o.epics_order_id = epics_orders.epics_order_id
      AND epics_orders.epics_order_type_id IN(#{type.id})
      INNER JOIN epics_stock_details s ON s.epics_stock_details_id = o.epics_stock_details_id
      AND s.epics_products_id=#{item.id} INNER JOIN epics_stocks e 
      ON e.epics_stock_id = s.epics_stock_id").where("e.grn_date <= ?
      AND e.epics_stock_id = ?", end_date, stock.id).sum(:quantity)
   
    return 0 if issued == '0' 
    return issued
  end

  def self.current_quantity(stock,item)
    EpicsStockDetails.where("epics_stock_id = ? AND epics_products_id = ?",
      stock.id,item.id).first.current_quantity 
  end
  ############################### stock card ends #########################################	

  def self.expired_items
    EpicsStockExpiryDates.joins("INNER JOIN epics_stock_details s 
    ON s.epics_stock_id = epics_stock_expiry_dates.epics_stock_details_id
    INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id AND p.expire = 1
    ").where("DATEDIFF(expiry_date,CURRENT_DATE()) <= 0                   
    AND current_quantity > 0").select("p.product_code code,p.name name, s.batch_number batch_number,
    current_quantity, min_stock,p.epics_products_id item_id,s.epics_stock_details_id, 
    max_stock, expiry_date").order("p.product_code,p.name,expiry_date").map do |r|
      {:item_code => r.code,:item_name => r.name,:item_id => r.item_id,
       :current_quantity => r.current_quantity, :expiry_date => r.expiry_date,
       :stock_details_id => r.epics_stock_details_id,:batch_number => r.batch_number
      }
    end
  end

  def self.disposed_items(start_date, end_date)
    order_type = EpicsOrderTypes.find_by_name('Board Off')
    start_date = start_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.strftime('%Y-%m-%d 23:59:59')

    EpicsOrders.joins("INNER JOIN epics_product_orders p                        
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0          
    AND epics_orders.epics_order_type_id = #{order_type.id}                     
    INNER JOIN epics_stock_details s                                            
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0     
    LEFT JOIN epics_stock_expiry_dates x 
    ON s.epics_stock_details_id = x.epics_stock_details_id AND x.voided = 0
    INNER JOIN epics_products ep ON ep.epics_products_id = s.epics_products_id 
    INNER JOIN epics_stocks e ON e.epics_stock_id = s.epics_stock_id 
    AND e.voided = 0").select("e.grn_date,e.invoice_number,p.quantity, 
    epics_orders.epics_location_id location_id, s.updated_at date_updated,                                                  
    s.batch_number,epics_orders.instructions void_reason, ep.epics_products_id,
    s.updated_at date_removed,ep.product_code,ep.name,
    s.received_quantity, p.quantity disposed_quantity ,x.expiry_date, 
    s.epics_stock_details_id").where("s.updated_at >= ? 
    AND s.updated_at <= ?",start_date, end_date).map do |r|
      {:item_code => r.product_code,:item_name => r.name,:item_id => r.epics_products_id,
       :disposed_quantity => r.quantity, :expiry_date => r.expiry_date,:batch_number => r.batch_number,
       :stock_details_id => r.epics_stock_details_id,:voided_at => r.date_removed,
       :void_reason => r.void_reason,:received_quantity => r.received_quantity
      }
    end
  end

  def self.audit(start_date, end_date)
    start_date = start_date.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date.strftime('%Y-%m-%d 23:59:59')

    sql=<<EOF
      SELECT c.pack_size,c.billing_charge,
      p.product_code item_code,p.name, c.unit_price, p.epics_products_id item_id,
      sum(s.received_quantity) received,sum(o.quantity) issued, s.received_quantity 
      FROM epics_stocks e INNER JOIN epics_stock_details s ON s.epics_stock_id = e.epics_stock_id
      AND e.created_at >= '#{start_date}' AND e.created_at <= '#{end_date}' 
      AND s.voided = 0 AND e.voided = 0
      LEFT JOIN epics_product_orders o ON o.epics_stock_details_id = s.epics_stock_details_id
      AND o.created_at >= '#{start_date}' AND o.created_at <= '#{end_date}' AND o.voided = 0
      INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id
      LEFT JOIN epics_item_costs c ON p.epics_products_id = c.epics_products_id
      GROUP BY s.epics_products_id 
EOF

    EpicsStockDetails.find_by_sql(sql).map do |r|
        balance = r.received_quantity
        value_spent = 'N/A'
        amount_in_hand = 'N/A'

        if r.issued
          balance = (r.received_quantity.to_f - r.issued.to_f)
          balance = balance.to_i if (balance.to_s[-2..-1] =='.0')
        else
          r.issued = 0
        end
        
        if not r.unit_price.blank? and not r.pack_size.blank?
          item_value = (r.received_quantity.to_f/r.pack_size.to_f)* r.unit_price.to_f
          value_spent = (r.issued.to_f/r.pack_size.to_f)* r.unit_price.to_f
          amount_in_hand = (item_value - value_spent)
        end

        {:item_code => r.item_code,:item_name => r.name,:item_id => r.item_id,
         :received_quantity => r.received_quantity, :issued => r.issued,
         :billing_charge => r.billing_charge,:unit_price => r.unit_price, 
         :balance => balance,:pack_size => r.pack_size,
         :value_spent => value_spent, :amount_in_hand => amount_in_hand
        }
      end
  end

  def self.received_items(start_date, end_date)

    sql=<<EOF
    SELECT p.product_code item_code,p.name item_name,
      sum(s.received_quantity) as received, sum(s.received_quantity - s.current_quantity) as issued
      FROM epics_stock_details s INNER JOIN epics_products p ON p.epics_products_id = s.epics_products_id
      INNER JOIN epics_stocks e ON e.epics_stock_id = s.epics_stock_id AND s.voided = 0
      WHERE e.grn_date BETWEEN '#{start_date}' AND '#{end_date}' group by p.epics_products_id
EOF

    EpicsStockDetails.find_by_sql(sql).map do |r|
        {:item_code => r.item_code,:item_name => r.item_name,
         :received => r.received, :issued => r.issued
        }
    end

  end

  #<<<<<<<<<<<<<<<<<<<<<<<< SD start >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
  def self.issues(item, results = {})
    order_type = EpicsOrderTypes.where("name IN (?)", ['Dispense', 'Donate']).collect{|x| x.id}

    EpicsOrders.joins("INNER JOIN epics_product_orders p 
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0
    AND epics_orders.epics_order_type_id IN (#{order_type.join(',')})
    INNER JOIN epics_stock_details s 
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0
    AND s.epics_products_id = #{item.id} INNER JOIN epics_stocks e
    ON e.epics_stock_id = s.epics_stock_id AND e.voided = 0").select("e.grn_date,
    e.invoice_number,p.quantity, epics_orders.epics_location_id location_id ,
    epics_orders.created_at dispensed_date, s.batch_number,
    epics_orders.epics_order_id,s.epics_stock_details_id,p.epics_product_order_id,
    s.epics_products_id,s.epics_stock_id").map do |r|
      dispensed_date = r.dispensed_date
      issued_to = EpicsLocation.find(r.location_id).name 

      if results[dispensed_date].blank?
        results[dispensed_date] = {}
      end

      if results[dispensed_date][r.invoice_number].blank?
        results[dispensed_date][r.invoice_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number].blank?
        results[dispensed_date][r.invoice_number][r.batch_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number][issued_to].blank?
        results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
          :issued => nil, 
          :epics_stock_id => nil, :epics_stock_details_id => nil,
          :epics_products_id => nil, :epics_order_id => nil,
          :epics_product_order_id => nil, :transaction => nil
        }
      end

      results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
        :issued => r.quantity ,
        :epics_stock_id => r.epics_stock_id, :epics_stock_details_id => r.epics_stock_details_id,
        :epics_products_id => r.epics_products_id, :epics_order_id => r.epics_order_id,
        :epics_product_order_id => r.epics_product_order_id, :transaction => 'issues' 
      }
    end

    return results
  end

  def self.receipts(item, results = {})
    stock_ids_which_are_not_receipts = [0]
    (EpicsExchange.all || []).map do |e|
      stock_ids_which_are_not_receipts << e.epics_stock_id
    end    

    (EpicsLendsOrBorrows.all || []).map do |l|
      stock_ids_which_are_not_receipts << l.epics_stock_id
    end    

    EpicsStock.joins(:epics_stock_details).where("epics_products_id = ? 
    AND epics_stock_details.voided = 0 
    AND epics_stock_details.epics_stock_id NOT IN(?)",
    item.id,stock_ids_which_are_not_receipts.compact).select("epics_stocks.*,
    epics_stock_details.*, epics_stocks.created_at created_at").map do |r|
      received_from = EpicsSupplier.find(r.epics_supplier_id).name
      grn_date = "#{r.grn_date} #{r.created_at.to_time.strftime('%H:%M:%S')}".to_time
      if results[grn_date].blank?
        results[grn_date] = {}
      end

      if results[grn_date][r.invoice_number].blank?
        results[grn_date][r.invoice_number] = {}
      end

      if results[grn_date][r.invoice_number][r.batch_number].blank?
        results[grn_date][r.invoice_number][r.batch_number] = {}
      end

      if results[grn_date][r.invoice_number][r.batch_number][received_from].blank?
        results[grn_date][r.invoice_number][r.batch_number][received_from] = {
          :received_quantity => nil , :current_quantity => nil ,
          :epics_stock_id => nil, :epics_stock_details_id => nil,
          :epics_products_id => nil, :transaction => nil
        }
      end

      results[grn_date][r.invoice_number][r.batch_number][received_from] = {
        :received_quantity => r.received_quantity , 
        :current_quantity => r.current_quantity ,
        :epics_stock_id => r.epics_stock_id, 
        :epics_stock_details_id => r.epics_stock_details_id,
        :epics_products_id => r.epics_products_id, :transaction => 'receipts' 
      }
    end

    return results
  end

  def self.positive_adjustments(item, results = {})
    stock_ids_which_are_not_receipts = [0]
    (EpicsExchange.all || []).map do |e|
      stock_ids_which_are_not_receipts << e.epics_stock_id
    end    

    (EpicsLendsOrBorrows.all || []).map do |l|
      stock_ids_which_are_not_receipts << l.epics_stock_id
    end    

    EpicsStock.joins("INNER JOIN epics_stock_details s 
    ON s.epics_stock_id = epics_stocks.epics_stock_id AND s.voided = 0
    AND s.epics_products_id = #{item.id} 
    AND s.epics_stock_id IN(#{stock_ids_which_are_not_receipts.compact.join(',')})
    LEFT JOIN epics_exchanges x ON x.epics_stock_id = s.epics_stock_id
    AND x.voided = 0 LEFT JOIN epics_lends_or_borrows b 
    ON b.epics_stock_id = s.epics_stock_id AND b.voided = 0").select("epics_stocks.*, 
    s.*, x.epics_location_id exchange_location_id, x.epics_exchange_id,b.epics_lends_or_borrows_id,
    b.facility borrow_location_id, epics_stocks.created_at created_at").map do |r|
      grn_date = "#{r.grn_date} #{r.created_at.to_time.strftime('%H:%M:%S')}".to_time

      if not r.exchange_location_id.blank?
        received_from = EpicsLocation.find(r.exchange_location_id).name 
        transaction = 'positive_adjustments:exchange'
      elsif not r.borrow_location_id.blank?
        received_from = EpicsLocation.find(r.borrow_location_id).name 
        transaction = 'positive_adjustments:borrow'
      end

      if results[grn_date].blank?
        results[grn_date] = {}
      end

      if results[grn_date][r.invoice_number].blank?
        results[grn_date][r.invoice_number] = {}
      end

      if results[grn_date][r.invoice_number][r.batch_number].blank?
        results[grn_date][r.invoice_number][r.batch_number] = {}
      end

      if results[grn_date][r.invoice_number][r.batch_number][received_from].blank?
        results[grn_date][r.invoice_number][r.batch_number][received_from] = {
          :quantity_received => nil ,
          :epics_stock_id => nil, :epics_stock_details_id => nil,
          :epics_products_id => nil, :epics_order_id => nil,
          :epics_product_order_id => nil , :epics_exchange_id => nil,
          :epics_lends_or_borrows_id => nil ,:transaction => nil
        }
      end

      results[grn_date][r.invoice_number][r.batch_number][received_from] = {
        :quantity_received => r.received_quantity ,
        :epics_stock_id => r.epics_stock_id, :epics_stock_details_id => r.epics_stock_details_id,
        :epics_products_id => r.epics_products_id, 
        :epics_exchange_id => r.epics_exchange_id,:transaction => transaction ,
        :epics_lends_or_borrows_id => r.epics_lends_or_borrows_id 
      }
    end

    return results
  end

  def self.negative_adjustments(item , results = {})
    order_type = EpicsOrderTypes.where("name IN('Lend','Exchange','Return')").map(&:epics_order_type_id)

    EpicsOrders.joins("INNER JOIN epics_product_orders p 
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0
    AND epics_orders.epics_order_type_id IN(#{order_type.join(',')})
    INNER JOIN epics_stock_details s 
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0
    AND s.epics_products_id = #{item.id} INNER JOIN epics_stocks e
    ON e.epics_stock_id = s.epics_stock_id AND e.voided = 0").select("e.grn_date,
    e.invoice_number,p.quantity, epics_orders.epics_location_id location_id ,
    epics_orders.created_at dispensed_date, s.batch_number,s.epics_stock_details_id,
    epics_orders.epics_order_id,p.epics_product_order_id,epics_orders.epics_order_type_id,
    s.epics_products_id").map do |r|
      dispensed_date = r.dispensed_date
      issued_to = EpicsLocation.find(r.location_id).name 

      if results[dispensed_date].blank?
        results[dispensed_date] = {}
      end

      if results[dispensed_date][r.invoice_number].blank?
        results[dispensed_date][r.invoice_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number].blank?
        results[dispensed_date][r.invoice_number][r.batch_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number][issued_to].blank?
        results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
          :quantity_given_out => nil , :epics_stock_details_id => nil,
          :epics_products_id => nil, :epics_order_id => nil,
          :epics_product_order_id => nil, :transaction => nil
        }
      end

      results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
        :quantity_given_out => r.quantity ,
        :epics_stock_details_id => r.epics_stock_details_id,
        :epics_products_id => r.epics_products_id, :epicis_order_id => r.epics_order_id,
        :epics_product_order_id => r.epics_product_order_id, 
        :transaction => "negative_adjustments:#{EpicsOrderTypes.find(r.epics_order_type_id).name}"
      }
    end

    return results
  end

  def self.losses(item, results = {})
    order_type = EpicsOrderTypes.find_by_name('Board Off')

    EpicsOrders.joins("INNER JOIN epics_product_orders p 
    ON p.epics_order_id = epics_orders.epics_order_id AND p.voided = 0
    AND epics_orders.epics_order_type_id = #{order_type.id}
    INNER JOIN epics_stock_details s 
    ON s.epics_stock_details_id = p.epics_stock_details_id AND s.voided = 0
    AND s.epics_products_id = #{item.id} INNER JOIN epics_stocks e
    ON e.epics_stock_id = s.epics_stock_id AND e.voided = 0").select("e.grn_date,
    e.invoice_number,p.quantity, epics_orders.epics_location_id location_id ,
    s.updated_at date_updated,s.batch_number,epics_orders.instructions,
    epics_orders.epics_order_id, p.epics_product_order_id,
    s.epics_stock_details_id, s.epics_products_id").map do |r|
      dispensed_date = r.date_updated
      issued_to = r.instructions.titleize rescue 'Unknown'

      if results[dispensed_date].blank?
        results[dispensed_date] = {}
      end

      if results[dispensed_date][r.invoice_number].blank?
        results[dispensed_date][r.invoice_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number].blank?
        results[dispensed_date][r.invoice_number][r.batch_number] = {}
      end

      if results[dispensed_date][r.invoice_number][r.batch_number][issued_to].blank?
        results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
          :issued => nil , 
          :epics_stock_details_id => nil,
          :epics_products_id => nil, :epics_order_id => nil,
          :epics_product_order_id => nil ,:transaction => nil
        }
      end

      results[dispensed_date][r.invoice_number][r.batch_number][issued_to] = {
        :losses => r.quantity, 
        :epics_stock_details_id => r.epics_stock_details_id,
        :epics_products_id => r.epics_products_id, :epics_order_id => r.epics_order_id,
        :epics_product_order_id => r.epics_product_order_id, :transaction => 'board off'
      }
    end

    return results
  end

  #<<<<<<<<<<<<<<<<<<<<<<<< SD end >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#

end
