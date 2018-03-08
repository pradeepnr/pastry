defmodule PastryNode do
  use GenServer
  @hash_size_in_bits 128
  @base_size_in_bits 4
  @hash_size (@hash_size_in_bits) / (@base_size_in_bits) |> round
  # @encoding_size :math.pow(2, @base_size_in_bits) |> round 
  # @rows @hash_size #32
  # @colmns @encoding_size #16
  
  def init({myHash, neighHash}) do
    state = %{my_hash: myHash, 
              neigh_hash: neighHash,
              curr_hop: 0, 
              routing_table: %{0=>%{}},
              left_leaf_set: [],
              right_leaf_set: []
              }
    {:ok, state}
  end

  def handle_call(:perform_join, _from, state) do
    #IO.puts ":perform_join"
    myHash = Map.get(state, :my_hash)
    neighHash = Map.get(state, :neigh_hash)
    case neighHash do
      nil -> #first node
        GenServer.cast(:manager, :create_next_node)
        {:reply, nil, state}
      _ ->
        hop = 0
        hop = GenServer.call(:"#{neighHash}", {:join, myHash, hop})
        {:reply, nil, Map.put(state, :total_hops, hop)}
    end
  end

  def handle_call({:join, newHash, hop}, _from, state) do
    hop = hop + 1
    #IO.puts ":join"
    myHash = Map.get(state, :my_hash)
    leftLeafSet = Map.get(state, :left_leaf_set)
    rightLeafSet = Map.get(state, :right_leaf_set)

    misMatchPos = Utility.get_mismatch_index(newHash, myHash)
    misMatchNewChar = String.at(newHash, misMatchPos)
    routingTable = Map.get(state, :routing_table)

    #forward logic
    newHop =
    cond do
      Utility.is_hash_with_in_leaf_set_Range(newHash, myHash, {leftLeafSet, rightLeafSet}) ->
        nearestNode = Utility.get_nearest_node(newHash, myHash, {leftLeafSet, rightLeafSet}, routingTable)
        cond do
          nearestNode != myHash ->
            GenServer.call(:"#{nearestNode}", {:join, newHash, hop})    
          true ->
            hop
        end
      Map.has_key?(routingTable, misMatchPos) && (Map.get(routingTable, misMatchPos) |> Map.has_key?(misMatchNewChar)) ->
        hash = Map.get(routingTable, misMatchPos) |> Map.get(misMatchNewChar)
        GenServer.call(:"#{hash}", {:join, newHash, hop})
      true ->
        nearestNode = Utility.get_nearest_node(newHash, myHash, {leftLeafSet, rightLeafSet}, routingTable)
        cond do
          nearestNode != myHash ->
            GenServer.call(:"#{nearestNode}", {:join, newHash, hop})    
          true ->
            #IO.puts "Reached destination"
            hop
        end
    end

    # sending my hash, routing table and leaf set
    GenServer.cast(:"#{newHash}", {:update_row_leaf_set, myHash, Map.get(routingTable, misMatchPos), leftLeafSet, rightLeafSet})

    #update my leaf set
    {leftLeafSet, rightLeafSet} = Utility.update_leaf_set(myHash, {leftLeafSet, rightLeafSet}, newHash)
    state = Map.put(state, :left_leaf_set, leftLeafSet)
    state = Map.put(state, :right_leaf_set, rightLeafSet)

    #update my routing table
    routingTable = Utility.add_hash_to_routing_table(myHash, routingTable, newHash)
    state = Map.put(state, :routing_table, routingTable)

    {:reply, newHop, state}
  end

  def handle_call(:print, _from, state) do
    routingTable = Map.get(state, :routing_table)
    leftLeafSet = Map.get(state, :left_leaf_set)
    rightLeafSet = Map.get(state, :right_leaf_set)
    myHash = Map.get(state, :my_hash)
    IO.puts "Table #{myHash} ->"
    IO.inspect routingTable
    IO.inspect leftLeafSet
    IO.inspect rightLeafSet
    IO.puts ""
    IO.puts ""
    {:reply, nil, state}
  end

  def handle_cast({:update_row_leaf_set, neighHash, neighRow, neighLeftLeafSet, neighRightLeafSet}, state) do
    #IO.puts ":update_row_leaf_set"
    myHash = Map.get(state, :my_hash)
    myRoutingTable = Map.get(state, :routing_table)
    leftLeafSet = Map.get(state, :left_leaf_set)
    rightLeafSet = Map.get(state, :right_leaf_set)
    misMatchPos = Utility.get_mismatch_index(myHash, neighHash)
    cummulativeLeafSet = [neighHash | neighLeftLeafSet]
    cummulativeLeafSet = Enum.concat(cummulativeLeafSet, neighRightLeafSet)
    routingTableList =
    cond do
      neighRow == nil ->
        []
      true ->
        Map.values(neighRow)
    end
    completeNodeList = Enum.concat(cummulativeLeafSet, routingTableList)

    #update row
    updatedRow = 
    cond do
      Map.has_key?(myRoutingTable, misMatchPos) == false and neighRow == nil ->
        %{}
      Map.has_key?(myRoutingTable, misMatchPos) == false and neighRow != nil->
        Utility.update_row(myHash, %{}, neighRow)
      Map.has_key?(myRoutingTable, misMatchPos) == true and neighRow == nil ->
        Map.get(myRoutingTable, misMatchPos)
      true ->
        currRow = Map.get(myRoutingTable, misMatchPos)
        Utility.update_row(myHash, currRow, neighRow)
    end
    updatedRoutingTable = Map.put(myRoutingTable, misMatchPos, updatedRow)
    #updatedRoutingTable = Utility.add_hash_to_routing_table(myHash, updatedRoutingTable, neighHash)
    updatedRoutingTable =
    Enum.reduce(
      cummulativeLeafSet,
      updatedRoutingTable, #accumulator
      fn(newHash, routingTableAcc) ->
        Utility.add_hash_to_routing_table(myHash, routingTableAcc, newHash)
      end)
    state = Map.put(state, :routing_table, updatedRoutingTable)

    #update leaf set
    {updatedLeftLeafSet, updatedRightLeafSet} =
    Enum.reduce(
      completeNodeList,
      {leftLeafSet, rightLeafSet},
      fn(leaf, {leftLeafSetAcc, rightLeafSetAcc}) ->
        cond do
          leaf != myHash and
              (leaf in leftLeafSetAcc) == false and
              (leaf in rightLeafSetAcc) == false ->
            Utility.update_leaf_set(myHash, {leftLeafSetAcc, rightLeafSetAcc}, leaf)
          true -> {leftLeafSetAcc, rightLeafSetAcc}
        end
      end)
    state = Map.put(state, :left_leaf_set, updatedLeftLeafSet)
    state = Map.put(state, :right_leaf_set, updatedRightLeafSet)
    
    currHop = Map.get(state, :curr_hop)
    totalHops = Map.get(state, :total_hops)
    if currHop+1 == totalHops do
        # send updated leaf set and routing table to all the hash in routing table and leaf set
        # send to leaf set
        totalLeafSet = Enum.concat(updatedLeftLeafSet, updatedRightLeafSet)
        Enum.map(totalLeafSet, 
          fn(leaf) ->
            GenServer.cast(:"#{leaf}", {:update_routing_table_leaf_set, myHash, updatedRoutingTable, updatedLeftLeafSet, updatedRightLeafSet})
          end)
        
        #send to routing table
        Enum.map(0..@hash_size-1,
          fn(v) ->
            if(Map.has_key?(updatedRoutingTable, v)) do
              row = Map.get(updatedRoutingTable, v)
              rowList = Map.values(row)
              Enum.map(rowList,
                fn(cell) ->
                  GenServer.cast(:"#{cell}", {:update_routing_table_leaf_set, myHash, updatedRoutingTable, updatedLeftLeafSet, updatedRightLeafSet})
                end)
            end
          end)
        GenServer.cast(:manager, :create_next_node)
    end
    state = Map.put(state, :curr_hop, currHop+1)

    {:noreply, state}
  end

  def handle_cast({:update_routing_table_leaf_set, neighHash, neighRoutingTable, neighLeftLeafSet, neighRightLeafSet}, state) do
    #IO.puts ":update_routing_table_leaf_set"
    myHash = Map.get(state, :my_hash)
    myRoutingTable = Map.get(state, :routing_table)

    #update leaf set
    leftLeafSet = Map.get(state, :left_leaf_set)
    rightLeafSet = Map.get(state, :right_leaf_set)
    routingTableList = Utility.get_list_of_has_from_routing_table(myRoutingTable)
    cummulativeLeafSet = [neighHash | neighLeftLeafSet]
    cummulativeLeafSet = Enum.concat(cummulativeLeafSet, neighRightLeafSet)
    completeNodeList = Enum.concat(cummulativeLeafSet, routingTableList)
    
    {updatedLeftLeafSet, updatedRightLeafSet} =
    Enum.reduce(
      completeNodeList,
      {leftLeafSet, rightLeafSet},
      fn(leaf, {leftLeafSetAcc, rightLeafSetAcc}) ->
        cond do
          leaf != myHash and 
              Utility.is_hash_with_in_leaf_set_Range(leaf, myHash, {leftLeafSetAcc, rightLeafSetAcc}) and
              (leaf in leftLeafSetAcc) == false and
              (leaf in rightLeafSetAcc) == false ->
            Utility.update_leaf_set(myHash, {leftLeafSetAcc, rightLeafSetAcc}, leaf)
          true -> {leftLeafSetAcc, rightLeafSetAcc}
        end
      end)
    state = Map.put(state, :left_leaf_set, updatedLeftLeafSet)
    state = Map.put(state, :right_leaf_set, updatedRightLeafSet)

    #update routing table
    updatedRoutingTable = Utility.update_routing_table(myHash, neighHash, myRoutingTable, neighRoutingTable)
    #updatedRoutingTable = Utility.add_hash_to_routing_table(myHash, updatedRoutingTable, neighHash)
    updatedRoutingTable =
    Enum.reduce(
      cummulativeLeafSet,
      updatedRoutingTable, #accumulator
      fn(newHash, routingTableAcc) ->
        Utility.add_hash_to_routing_table(myHash, routingTableAcc, newHash)
      end)
    state = Map.put(state, :routing_table, updatedRoutingTable)
    {:noreply, state}
  end

  def handle_cast({:send_request, totalRequests, totalNodes, nodeId, requestSent}, state) do
    randomNode = Utility.get_random_node_id(totalNodes, nodeId)
    randomNodeHash = Utility.get_hash("Node#{randomNode}")
    GenServer.cast(self(), {:forward_request, randomNodeHash, -1})
    
    if (requestSent + 1) < totalRequests do
      Process.send_after(self(), {:send_request, totalRequests, totalNodes, nodeId, requestSent + 1}, 1_000)
    end
    {:noreply, state}
  end

  def handle_cast({:forward_request, destination, hop}, state) do
    #implement the logic here
    hop = hop + 1
    myHash = Map.get(state, :my_hash)
    myRoutingTable = Map.get(state, :routing_table)
    leftLeafSet = Map.get(state, :left_leaf_set)
    rightLeafSet = Map.get(state, :right_leaf_set)

    misMatchPos = Utility.get_mismatch_index(destination, myHash)
    misMatchChar = String.at(destination, misMatchPos)
    cond do
      destination == myHash ->
        GenServer.cast(:manager, {:msg_reached_destination, hop})
      leftLeafSet != [] and  destination >= hd(leftLeafSet) and destination < myHash ->
        # destination is in leftLeafSet
        nearest = Enum.min_by(leftLeafSet, fn(hash) -> Utility.get_distance(hash, destination) end)
        nearest = Utility.get_closer_hash(destination, nearest, myHash)
        cond do
          nearest == myHash ->
            GenServer.cast(:manager, {:msg_reached_destination, hop})
          true ->
            GenServer.cast(:"#{nearest}", {:forward_request, destination, hop})
        end
      rightLeafSet != [] and  destination <= hd(rightLeafSet) and destination > myHash ->
        # destination is in rightLeafSet
        nearest = Enum.min_by(rightLeafSet, fn(hash) -> Utility.get_distance(hash, destination) end)
        nearest = Utility.get_closer_hash(destination, nearest, myHash)
        cond do
          nearest == myHash ->
            GenServer.cast(:manager, {:msg_reached_destination, hop})
          true ->
            GenServer.cast(:"#{nearest}", {:forward_request, destination, hop})
        end
      
      Map.has_key?(myRoutingTable, misMatchPos) and Map.get(myRoutingTable, misMatchPos) |> Map.has_key?(misMatchChar) ->
        fwdAddress = Map.get(myRoutingTable, misMatchPos) |> Map.get(misMatchChar)
        GenServer.cast(:"#{fwdAddress}", {:forward_request, destination, hop})
      
      true ->
        fwdAddress = Utility.get_nearest_node(destination, myHash, {leftLeafSet, rightLeafSet}, myRoutingTable)
        GenServer.cast(:"#{fwdAddress}", {:forward_request, destination, hop})
        #IO.puts "forwarding to #{fwdAddress} destination ->#{destination}"
    end

    {:noreply, state}
  end

  def handle_info({:send_request, totalRequests, totalNodes, nodeId, requestSent}, state) do
    GenServer.cast(self(), {:send_request, totalRequests, totalNodes, nodeId, requestSent})
  {:noreply, state}
end

end