defmodule Utility do
  @base_16_array ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
  @left_size 8

  def get_leaf_size() do
    @left_size
  end

  def isInteger(val) do
        try do
          _ = String.to_integer(val)
          true
        catch
          _what, _value -> 
            IO.puts "numNodes must be integer"
            false
        end
    end

  def print_valid_format_info do
    IO.puts "Valid format:"
    IO.puts "project3 numNodes numRequests"
    IO.puts "  numNodes: Integer type"
    IO.puts "  numRequests: Integer type"
  end

  def get_hash(nodeid) do
    Base.encode16(:crypto.hash(:md5, nodeid))
  end

  def get_mismatch_index(nodeId1, nodeId2) do
    get_mismatch(nodeId1, nodeId2, 0)
  end
  
  defp get_mismatch(nodeId1, nodeId2, pos) do
    cond do
      pos < String.length(nodeId1) and pos < String.length(nodeId2) and String.at(nodeId1, pos) == String.at(nodeId2, pos) ->
        get_mismatch(nodeId1, nodeId2, pos+1)
      true ->
        pos
    end
  end

  def test() do
    IO.puts ""
    #Enum.map(@base_16_array, fn v-> IO.puts v end)
  end

  def update_routing_table(currHash, newHash, currRoutingTable, newRoutingTable) do
    misMatchPos = get_mismatch_index(currHash, newHash)

    newRoutingTable = remove_hash_from_table(currHash, misMatchPos, newRoutingTable)

    Enum.reduce(
      0..misMatchPos,
      currRoutingTable,
      fn(row, currRoutingTableAcc) ->
        cond do
          Map.has_key?(currRoutingTableAcc, row) == false and Map.has_key?(newRoutingTable, row) == false ->
            currRoutingTableAcc
          Map.has_key?(currRoutingTableAcc, row) == false ->
            addNewRow = Map.get(newRoutingTable, row)
            Map.put(currRoutingTableAcc, row, addNewRow)
          Map.has_key?(newRoutingTable, row) == false ->
            currRoutingTableAcc
          true ->
            currRow = Map.get(currRoutingTableAcc, row)
            newRow = Map.get(newRoutingTable, row)
            addNewRow = update_row(currHash, currRow, newRow)
            Map.put(currRoutingTableAcc, row, addNewRow)
        end
      end)
  end

  def add_hash_to_routing_table(currHash, currRoutingTable, newHash) do
    misMatchPos = Utility.get_mismatch_index(newHash, currHash)
    misMatchNewChar = String.at(newHash, misMatchPos)
    cond do
      Map.has_key?(currRoutingTable, misMatchPos) == false ->
        Map.put(currRoutingTable, misMatchPos, %{misMatchNewChar => newHash})
      Map.get(currRoutingTable, misMatchPos) |> Map.has_key?(misMatchNewChar) == false ->
        row = Map.get(currRoutingTable, misMatchPos) |> Map.put(misMatchNewChar, newHash)
        Map.put(currRoutingTable, misMatchPos, row)
      true ->
        oldHash = Map.get(currRoutingTable, misMatchPos) |> Map.get(misMatchNewChar)
        nearest = get_closer_hash(currHash, oldHash, newHash)
        cond do
          nearest == oldHash ->
            currRoutingTable
          true ->
            row = Map.get(currRoutingTable, misMatchPos) |> Map.put(misMatchNewChar, newHash)
            Map.put(currRoutingTable, misMatchPos, row)
        end
    end
  end

  def remove_hash_from_table(currHash, misMatchPos, newRoutingTable) do
    misMatchChCurr = String.at(currHash, misMatchPos)
    cond do
      newRoutingTable != nil and Map.has_key?(newRoutingTable, misMatchPos) ->
        newMisMatchRow = Map.get(newRoutingTable, misMatchPos) |> Map.delete(misMatchChCurr)
        Map.put(newRoutingTable, misMatchPos, newMisMatchRow)
      true ->
        newRoutingTable
    end
  end

  #returns updated currRow with newRow's values which are closer to currHash
  def update_row(currHash, currRow, newRow) do
    update_row_pos(currHash, currRow, newRow, @base_16_array)
  end

  defp update_row_pos(_currHash, currRow, _newRow, []) do
    currRow
  end

  defp update_row_pos(currHash, currRow, newRow, [pos | tail]) do
    currValAtPos = Map.get(currRow, pos)
    newValAtPos = Map.get(newRow, pos)
    cond do
      currValAtPos == nil and newValAtPos == nil ->
        update_row_pos(currHash, currRow, newRow, tail)
      currValAtPos == nil ->
        update_row_pos(currHash, Map.put(currRow, pos, newValAtPos), newRow, tail)
      newValAtPos == nil ->
        update_row_pos(currHash, currRow, newRow, tail)
      true ->
        nearestVal = get_closer_hash(currHash, currValAtPos, newValAtPos)
        update_row_pos(currHash, Map.put(currRow, pos, nearestVal), newRow, tail)
    end
  end

  def get_distance(hashOne, hashTwo) do
    {hashOneNum, _} = Integer.parse(hashOne, 16)
    {hashTwoNum, _} = Integer.parse(hashTwo, 16)
    abs(hashOneNum - hashTwoNum)
  end

  def get_closer_hash(currHash, oldHash, newHash) do
    cond do
      get_distance(currHash, oldHash) <= get_distance(currHash, newHash) ->
        oldHash
      true->
        newHash
    end
  end

  def is_hash_with_in_leaf_set_Range(newHash, myHash, {[], []}) do
    cond do
      newHash == myHash -> true
      true -> false
    end
  end

  def is_hash_with_in_leaf_set_Range(newHash, myHash, {[], rightLeafSet}) do
    [highest | _] = rightLeafSet
    cond do
      newHash >= myHash and newHash <= highest -> true
      true -> false;
    end
  end

  def is_hash_with_in_leaf_set_Range(newHash, myHash, {leftLeafSet, []}) do
    [lowest | _] = leftLeafSet
    cond do
      newHash >= lowest and newHash <= myHash -> true
      true -> false;
    end
  end

  def is_hash_with_in_leaf_set_Range(newHash, _myHash, {leftLeafSet, rightLeafSet}) do
    [lowest | _] = leftLeafSet
    [highest | _] = rightLeafSet
    cond do
      newHash >= lowest and newHash <= highest -> true
      true -> false;
    end
  end

  # Assumptions
  # 1) newHash != currHash
  # 2) left and right leaf set is sorted
  # 3) newHash is within leaf set range
  def update_leaf_set(currHash, {leftLeafSet, rightLeafSet}, newHash) do
    case newHash < currHash do
      true -> # add it to left leaf set
        cond do
          leftLeafSet == [] ->
            {[newHash], rightLeafSet}
          length(leftLeafSet) < @left_size ->
            leafSet = [newHash | leftLeafSet]
            {Enum.sort(leafSet), rightLeafSet}
          is_hash_with_in_leaf_set_Range(newHash, currHash, {leftLeafSet, rightLeafSet}) ->
            [_ | tail] = leftLeafSet
            newLeftLeaftSet = [newHash | tail]
            {Enum.sort(newLeftLeaftSet), rightLeafSet}
          true ->
            {leftLeafSet, rightLeafSet}
        end
      false -> # add it to right left set
        cond do
          rightLeafSet == [] ->
            {leftLeafSet, [newHash]}
          length(rightLeafSet) < @left_size ->
            leafSet = [newHash | rightLeafSet]
            {leftLeafSet, Enum.sort(leafSet, &(&1 >= &2))}
          is_hash_with_in_leaf_set_Range(newHash, currHash, {leftLeafSet, rightLeafSet}) ->
            [_ | tail] = rightLeafSet
            newRightLeaftSet = [newHash | tail]
            {leftLeafSet, Enum.sort(newRightLeaftSet, &(&1 >= &2))}
          true ->
            {leftLeafSet, rightLeafSet}
        end
    end
  end

  def get_nearest_node(newHash, myHash, {leftLeafSet, rightLeafSet}, routingTable) do
    routingTableList = get_list_of_has_from_routing_table(routingTable)
    leftLeafSet = [myHash | leftLeafSet]
    leafSet = Enum.concat(leftLeafSet, rightLeafSet)
    hashList = Enum.concat(leafSet, routingTableList)
    Enum.min_by(hashList, fn(hash) -> get_distance(hash, newHash) end)
  end

  def get_list_of_has_from_routing_table(routingTable) do
    Enum.reduce(
      0..31,
      [], # initial value of accumulator
      fn (rowNum, routing_table_acc) ->
        cond do
          Map.has_key?(routingTable, rowNum) ->
            Map.get(routingTable, rowNum) |> Map.values() |> Enum.concat(routing_table_acc)
          true ->
            routing_table_acc
        end
      end)
  end

  def get_random_node_id(totalNodes, nodeId) do
    randomNode = Enum.random(0..(totalNodes-1))
    cond do
      randomNode == nodeId and nodeId == 0 ->
        randomNode + 1
      randomNode == nodeId and nodeId == (totalNodes-1) ->
        randomNode - 1
      true ->
        randomNode
    end
  end

end
