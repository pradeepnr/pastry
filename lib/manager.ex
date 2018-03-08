defmodule Manager do
  use GenServer

  def start_process(config) do
    numNodes = Map.get(config, :total_nodes)
    numRequests = Map.get(config, :total_requests)
    IO.puts "Starting #{numNodes} nodes with #{numRequests} requests"
    {:ok, _pid} = GenServer.start_link(__MODULE__, config, name: :manager)
  end
  
  def init(state) do
    state = Map.put(state, :nodes_created, 0)
    state = Map.put(state, :request_recived, 0)
    state = Map.put(state, :current_hop, 0)
    GenServer.cast(:manager, :create_next_node)
    {:ok, state}
  end

  #callbacks
  def handle_cast(:create_next_node, state) do
    #IO.puts "create_next_node"
    nodesCreated = Map.get(state, :nodes_created)
    totalNodes = Map.get(state, :total_nodes)
    cond do
      nodesCreated == 0 ->
        nodeHash = Utility.get_hash("Node#{nodesCreated}")
        GenServer.start_link(PastryNode, {nodeHash, nil}, name: :"#{nodeHash}")
        state = Map.put(state, :nodes_created, nodesCreated+1)
        #perform join using call
        GenServer.call(:"#{nodeHash}", :perform_join)
        {:noreply, state}

      nodesCreated < totalNodes ->
        nodeHash = Utility.get_hash("Node#{nodesCreated}")
        neighHash = Utility.get_hash("Node#{nodesCreated-1}")
        GenServer.start_link(PastryNode, {nodeHash, neighHash}, name: :"#{nodeHash}")
        state = Map.put(state, :nodes_created, nodesCreated+1)
        #perform join using call
        GenServer.call(:"#{nodeHash}", :perform_join)
        {:noreply, state}
      true ->
        IO.puts "Leaf set and routing table initialization is done."
        IO.puts "Sending message at the rate of 1 Request/Second"
        GenServer.cast(:manager, :create_nodes_done)
        {:noreply, state}
    end
  end

  def handle_cast(:create_nodes_done, state) do
    totalNodes = Map.get(state, :total_nodes)
    totalRequests = Map.get(state, :total_requests)
    Enum.map(0..(totalNodes-1), fn (v)-> 
        hash = Utility.get_hash("Node#{v}")
        #GenServer.call(:"#{hash}", :print)
        GenServer.cast(:"#{hash}", {:send_request, totalRequests, totalNodes, v, 0})
        end)
    {:noreply, state}
  end

  def handle_cast({:msg_reached_destination, hop}, state) do
    requestRecived = Map.get(state, :request_recived) + 1
    #IO.puts "received msg #{requestRecived}"
    currentHop = Map.get(state, :current_hop) + hop
    totalNodes = Map.get(state, :total_nodes)
    totalRequests = Map.get(state, :total_requests)
    
      
    if requestRecived >= (totalNodes * totalRequests) do
        avg = currentHop / (totalNodes * totalRequests)
        IO.puts "Average number of hops to deliver message -> #{avg}"
        mainPid = Map.get(state, :main_pid)    
        send(mainPid, :close)
    end
    state = Map.put(state, :current_hop, currentHop)
    state = Map.put(state, :request_recived, requestRecived)
    {:noreply, state}
  end

end
