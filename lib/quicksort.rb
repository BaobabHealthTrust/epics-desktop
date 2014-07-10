module QuickSort

  def self.quicksort(list, p, r)
    if p < r then
        q = self.partition(list, p, r)
        self.quicksort(list, p, q-1)
        self.quicksort(list, q+1, r)
    end
    return list
  end
 
  def self.partition(list, p, r)
    pivot = list[r]
    i = p - 1
    p.upto(r-1) do |j|
        if list[j] <= pivot
            i = i+1
            list[i], list[j] = list[j],list[i]
        end       
    end
    list[i+1],list[r] = list[r],list[i+1]
    return i + 1
  end    

end
