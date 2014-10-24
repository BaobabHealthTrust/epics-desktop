=begin
  This script was written by T. Mtonga to clean data as a result of a mistake made in querying stock details when
  issuing items
=end
require "csv"
$voidedPOrders = 0
$voidedOrders = 0
$voidedStock = 0
$multiple_stock_details = []
$multipleOrders = []
$suspectedRecords = Hash.new([])
$suspected = []
def start

  fix_hanging_stock_details()
  #To begin, get all users with records
  stock_creators = EpicsStock.all.collect { |x| x.creator }
  order_creators = EpicsOrders.all.collect { |x| x.creator}

  users = (stock_creators + order_creators).uniq

  total_suspected_records = 0
  puts "There are #{users.length} users to go through"
  user_count = Hash.new(0)
  # Next go through each user getting the stocks that they entered
  (users || []).each do |user|
    stock_entries = EpicsStock.where("creator = ? AND created_at <= ?",user, "2014-10-18").order("created_at ASC")
    puts "User #{user} has #{stock_entries.length} Stock Entries "

    (stock_entries || []).each_with_index do |record, index|
      current_entry = record
      next_entry = stock_entries[index + 1] rescue nil

      if next_entry.blank?
        user_count[user] += check_remaining_orders(user, current_entry)
      else
        user_count[user] += check_remaining_orders(user,current_entry, next_entry)
      end
    end
    puts "User #{user} has #{user_count[user]} suspect encounters"
    create_user_csv(user,$suspectedRecords[user])
  end

  (user_count.keys || []).each do |key|
    puts "User #{key} has #{user_count[key]} suspect encounters"
    total_suspected_records += user_count[key]
  end
  create_full_csv()
  puts "Voided #{$voidedPOrders} product orders, #{$voidedOrders} orders, #{$voidedStock} stock records "
  puts "Total Suspected Records : #{total_suspected_records}"
end

def check_remaining_orders(user, entry, next_entry = nil)


  if entry.epics_stock_details.length > 1
    $multiple_stock_details << entry
    return 0;
  else
    if entry.epics_stock_details.blank?
      void_epics_stock(entry)
      return 0
    end
    product = entry.epics_stock_details.first.epics_products_id
    if next_entry.blank?
      orders = EpicsOrders.where("creator = ? AND updated_at >= ? ", user, entry.created_at)
    else
      orders = EpicsOrders.where("creator = ? AND updated_at > ? AND updated_at < ? ", user, entry.created_at,next_entry.created_at)
    end


    suspectedOrders = 0
    (orders || []).each do |order|

      if order.epics_product_orders.length > 1
        $multipleOrders << order
      else
        product_issued = order.epics_product_orders.first.epics_stock_details.epics_products_id rescue nil

        if product_issued.blank?
          void_product_order(order.epics_product_orders.first)
          void_order(order)
        else
          if product != product_issued
            $suspectedRecords[user] << {:order => order.id, :product => product, :product_issued => product_issued,
                                 :amount => order.epics_product_orders.first.quantity,
                                 :stock_detail => order.epics_product_orders.first.epics_stock_details.id,
                                :stock_created_at => entry.created_at, :order_at => order.updated_at}

            $suspected << {:order => order.id, :product => product, :product_issued => product_issued,
                          :amount => order.epics_product_orders.first.quantity,
                          :product_order => order.epics_product_orders.first.id,
                          :stock_detail => order.epics_product_orders.first.epics_stock_details.id,
                          :stock_created_at => entry.created_at, :order_at => order.updated_at,
                          :order_creator => order.creator,:batch => order.epics_product_orders.first.epics_stock_details.batch_number.to_s,
                          :used_stock_created => order.epics_product_orders.first.epics_stock_details.epics_stock.created_at,
                          :stock_creator => order.epics_product_orders.first.epics_stock_details.epics_stock.creator
            }
            reverse_order_subtractions(order.epics_product_orders.first.epics_stock_details, order.epics_product_orders.first.quantity)
            suspectedOrders += 1
          end
        end

      end

    end
    return suspectedOrders
  end

end

def void_product_order(product_order)
  unless product_order.blank?
    product_order.voided = true
    product_order.save
    $voidedPOrders += 1
  end
end

def void_order(order)
  unless order.blank?
    order.voided = true
    order.save
    $voidedOrders += 1
  end
end

def void_epics_stock(stock)
  unless stock.blank?
    stock.voided = true
    stock.save
    $voidedStock += 1
  end
end

def create_user_csv(user, records)

  CSV.open("#{Rails.root}/doc/#{user}-Suspected Records.csv", "wb") do |csv|
    csv << ["Order ID", "Item Supposed To Be Dealing With", "Item Issued", "Amount Issued",
            "Stock Item Affected", "Stock Entered At", "Order Created At"]

    (records || []).each do |record|

      csv << [record[:order], record[:product], record[:product_issued],record[:amount],
              record[:stock_detail], record[:stock_created_at], record[:order_at]]
    end

  end

end

def create_full_csv()
  puts "Recreating product orders"
  CSV.open("#{Rails.root}/doc/Suspected Records.csv", "wb") do |csv|
    csv << ["Order ID","Product Order", "Item Supposed To Be Dealing With", "Item Issued","Batch Number", "Amount Issued",
            "Stock Item Affected","Check Stock Entry Time","Order Created At",
            "Used Stock Entry Time","Order Creator", "Stock Creator","New Stock Detail", "Status"]


    ($suspected || []).each do |record|
        csv << associate_order_to_right_stock(record)

    end

  end
end

def reverse_order_subtractions(stock_detail, quantity)
  stock_detail.current_quantity += quantity
  stock_detail.save
end

def associate_order_to_right_stock(record)

  #get right batch

  batch = EpicsStockDetails.find(:first,:conditions =>["batch_number = ? and current_quantity >= ? and epics_products_id = ?",
                                                       record[:batch],record[:amount],record[:product] ])

  if batch.blank?
    return [record[:order],record[:product_order] ,record[:product], record[:product_issued],record[:batch],record[:amount],
            record[:stock_detail], record[:stock_created_at], record[:order_at],
            record[:used_stock_created],record[:order_creator], record[:stock_creator]," " ,"Not reversed"]
  else
    EpicsOrders.transaction do

      item_order = EpicsProductOrders.find(record[:product_order])
      item_order.epics_stock_details_id = batch.id
      item_order.save

      batch.current_quantity = (batch.current_quantity - record[:amount].to_i)
      batch.save

      return [record[:order],record[:product_order], record[:product], record[:product_issued],record[:batch],record[:amount],
              record[:stock_detail], record[:stock_created_at], record[:order_at],
              record[:used_stock_created],record[:order_creator], record[:stock_creator],batch.id ,"Reversed"]
    end
  end

end

def fix_hanging_stock_details()
  stock_details = EpicsStockDetails.find_by_sql("select * from epics_stock_details where voided = 0 and
                        epics_stock_id IN (Select epics_stock_id  from epics_stocks where voided = 1)")


  (stock_details || []).each do |stock_detail|
    stock_detail.voided = true
    stock_detail.save
  end
end
start