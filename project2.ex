defmodule Project2 do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end


  # Initialized the state of node to {0, 0} -> {nodeID, count}
  def init(_) do
    {:ok, {0, 0, [], 1}}
  end

  def main(args) do
    # numNodes = Enum.at(args, 0) |> String.to_integer()
    toplogy = Enum.at(args, 1)
    algorithm = Enum.at(args, 2)
    # numNodes = args
    x = :math.sqrt((Enum.at(args, 0) |> String.to_integer())/4)
    x = round(Float.ceil(x))
    # numNodes = args
    numNodes =
      if toplogy == "3D" || toplogy == "torus" do
        4*x*x
      else
        Enum.at(args, 0) |> String.to_integer()
      end
    pids = createNodes(numNodes)

    case toplogy do
      "full" ->
        createFullNW(pids)
      "3D" ->
        create3D(pids,x)
      "rand2D" ->
        createRandom2DGrid(pids)
      "torus" ->
        createTorus(pids,x)
      "line" ->
        createLine(pids)
      "imp2D" ->
        createImpLine(pids)
      _ ->
        IO.puts "Invalid toplogy"
        System.halt(1)
    end

    createTable()
    start = System.monotonic_time(:microsecond)
    case algorithm do
      "gossip" ->
        gossip(numNodes, pids, start)
      "push-sum" ->
        pushSum(pids,start)
        loop()
    end
  end

  def loop() do
    loop()
  end

  def createTable do
    table = :ets.new(:table, [:named_table,:public])
    :ets.insert(table, {"count",0})
  end

  # `nodes` store the pid of each node as a list
  def createNodes(numNodes) do
    Enum.map((1..numNodes), fn x ->
      {:ok, pid} = start_link()
      set_state(pid, x)
      pid
    end)
  end

  # After creating a node, we keep the state of node as nodeID
  def set_state(pid, x) do
    GenServer.call(pid, {:setState, x})
  end

  # Selects a random node from a list and returns it
  def randomNode(list) do
    randomNode = Enum.random(list)
    randomNode
  end

  # Given a pid, it changes the state of it
  def updateCount(node, start, numNodes) do
    GenServer.call(node, {:updateCount, start, numNodes})
  end

  # Start gossip
  def gossip(numNodes, nodes, start) do
    random_number = :rand.uniform(numNodes)
    chosen_node = Enum.at(nodes, random_number-1)
    updateCount(chosen_node, start, numNodes)
    propagate_gossip(chosen_node, nodes, start)
  end

  def propagate_gossip(node, nodes, start) do
    count = getCount(node)
    numNodes = Enum.count(nodes)
    if count < 10 do
      neighbours = getNeighbours(node)
      random_neighbour = randomNode(neighbours) # selects a random neighbour
      neighbor_count = getCount(random_neighbour)
      updateCount(random_neighbour, start, numNodes)
      if neighbor_count == 0 do
        Task.start_link(Project2, :propagate_gossip, [random_neighbour,nodes, start])
      #   propagate_gossip(random_neighbour, nodes, start)
      end
      # propagate_gossip(node, nodes, start)
    else
      # true ->
      Process.exit(node, :normal)
    end
     propagate_gossip(node, nodes, start)
  end

  def pushSum(nodes, start) do
    numNodes = Enum.count(nodes)
    chosen_node = Enum.random(nodes)
    GenServer.cast(chosen_node, {:receivepushsum, 0, 0, start, numNodes})
  end

  def sendPushSum(random_node, s, w, start, numNodes) do
    GenServer.cast(random_node, {:receivepushsum, s, w, start, numNodes})
  end

  # Function to get the neighbours of a node
  def getNeighbours(node) do
    GenServer.call(node, {:getNeighbours})
  end


  # Function to get the current count of the number of messages received
  # State is unchaged, but we need to access the count from it.
  def getCount(node) do
    GenServer.call(node, {:getCount})
  end

  def randomArray(length, list \\ [])

  def randomArray(0, list) do
    list
  end
  def randomArray(length, list) do
    length-1 |> randomArray([random_number() | list])
  end

  defp random_number() do
    :rand.uniform() |> Float.round(2)
  end

  def check_neighbours(center, neighbour) do
    # j = Enum.find_index(nodes, fn c -> c == node end)
    # center = Enum.at(neghbours, j)
    if insideCircle(neighbour, center) do
      true
    else
      false
    end
  end

  def insideCircle(point, center) do
    {x, y} = point
    {p, q} = center
    distance = :math.pow(:math.pow((x-p), 2) + :math.pow((y-q), 2), 1/2)
    if distance <= 0.1 and distance > 0 do
      true
    else
      false
    end
  end

  def createFullNW(nodes) do
    neighbour_list = nodes
    Enum.each(nodes, fn x ->
      list = neighbour_list |> List.delete(x)
      GenServer.call(x, {:pass_list, list})
    end)
  end

  def createLine(nodes) do
    last_index = Enum.count(nodes) - 1
    # IO.puts last_index
    Enum.each(nodes, fn x ->
      a = Enum.find_index(nodes, fn (b) -> b == x end)
      # IO.puts a
      cond do
        a == 0 ->
          list = [Enum.at(nodes, 1)]
          GenServer.call(x, {:pass_list, list})
        a == last_index ->
          list = [Enum.at(nodes, last_index-1)]
          GenServer.call(x, {:pass_list, list})
        a>0 && a<last_index ->
           list = [Enum.at(nodes, a-1),Enum.at(nodes, a+1)]
           GenServer.call(x, {:pass_list, list})
      end
    end)
  end

  def createImpLine(nodes) do
    last_index = Enum.count(nodes) - 1
    # IO.puts last_index
    Enum.each(nodes, fn x ->
      a = Enum.find_index(nodes, fn (b) -> b == x end)
      # IO.puts a
      cond do
        a == 0 ->
          rem_nodes= Enum.slice(nodes,2..last_index)
          rand_node = Enum.random(rem_nodes)
          list = [Enum.at(nodes, 1),rand_node]
          GenServer.call(x, {:pass_list, list})
        a == last_index ->
          rem_nodes= Enum.slice(nodes,0..last_index-2)
          rand_node = Enum.random(rem_nodes)
          list = [Enum.at(nodes, last_index-1),rand_node]
          GenServer.call(x, {:pass_list, list})
        a >0 && a < last_index ->
          rem_nodes1 = Enum.slice(nodes,0..a-2)
          rem_nodes2 = Enum.slice(nodes,a+2,last_index)
          rem_nodes = rem_nodes1 ++ rem_nodes2
          rand_node = Enum.random(rem_nodes)
          list = [Enum.at(nodes, a-1),Enum.at(nodes, a+1),rand_node]
          GenServer.call(x, {:pass_list, list})
      end
    end)
  end

  def createRandom2DGrid(nodes) do
    n = Enum.count(nodes)
    x = randomArray(n)
    y = randomArray(n)
    coordinates = Enum.zip(x, y)
    neighbours = coordinates
    Enum.each(nodes, fn x ->
      i = Enum.find_index(nodes, fn b -> b == x end)
      center = Enum.fetch!(neighbours, i)
      count = Enum.count(nodes)
      a = Enum.filter((0..count-1), fn y -> check_neighbours(center, Enum.at(neighbours, y)) end)
      # IO.inspect a
      b = Enum.map_every(a, 1, fn x -> Enum.at(nodes, x) end)
      # IO.inspect b
      GenServer.call(x, {:pass_list, b})
      # indices
    end)
  end

  def create3D(nodes,x) do
    mesh = Enum.chunk_every(nodes, x)
    mesh1 = Enum.slice(mesh,0,x)
    mesh2 = Enum.slice(mesh,x,x)
    mesh3 = Enum.slice(mesh,(2*x),x)
    mesh4 = Enum.slice(mesh,(3*x),x)
    last_index = x-1

    # Mesh 1 neighbours
    Enum.each(mesh1,fn (elem) ->
        a = Enum.find_index(mesh1, fn (b) -> b == elem end)
        cond do
          a == 0 ->
            upper_list = Enum.at(mesh2,0)
            lower_list = Enum.at(mesh1,1)
            behind_list = []
            send_neighbour_outer3D(elem,upper_list,lower_list,behind_list,a,last_index)
          a == last_index ->
            upper_list = Enum.at(mesh1,last_index - 1)
            lower_list = Enum.at(mesh2,last_index)
            behind_list = []
            send_neighbour_outer3D(elem,upper_list,lower_list,behind_list,a,last_index)
          true ->
            upper_list = Enum.at(mesh1,a - 1)
            lower_list = Enum.at(mesh1,a + 1)
            behind_list = Enum.at(mesh2,a)
            send_neighbour_outer3D(elem,upper_list,lower_list,behind_list,a,last_index)
        end
    end)

    # Mesh 4 neighbours
    Enum.each(mesh4,fn (elem) ->
        a = Enum.find_index(mesh4, fn (b) -> b == elem end)
        cond do
          a == 0 ->
            upper_list = Enum.at(mesh3,0)
            lower_list = Enum.at(mesh4,1)
            front_list = []
            send_neighbour_outer3D(elem,upper_list,lower_list,front_list,a,last_index)
          a == last_index ->
            upper_list = Enum.at(mesh4,last_index - 1)
            lower_list = Enum.at(mesh3,last_index)
            front_list = []
            send_neighbour_outer3D(elem,upper_list,lower_list,front_list,a,last_index)
          true ->
            upper_list = Enum.at(mesh4,a - 1)
            lower_list = Enum.at(mesh4,a + 1)
            front_list = Enum.at(mesh3,a)
            send_neighbour_outer3D(elem,upper_list,lower_list,front_list,a,last_index)
        end
    end)

    # Mesh 2 neighbours
    Enum.each(mesh2,fn (elem) ->
        a = Enum.find_index(mesh2, fn (b) -> b == elem end)
        cond do
          a == 0 ->
            upper_list = []
            lower_list = Enum.at(mesh2,1)
            front_list = Enum.at(mesh1,0)
            behind_list = Enum.at(mesh3,0)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
          a == last_index ->
            upper_list = Enum.at(mesh2,last_index - 1)
            lower_list = []
            front_list = Enum.at(mesh1,last_index)
            behind_list = Enum.at(mesh3,last_index)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
          true ->
            upper_list = Enum.at(mesh2,a - 1)
            lower_list = Enum.at(mesh2,a + 1)
            front_list = Enum.at(mesh1,a)
            behind_list = Enum.at(mesh3,a)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
        end

    end)

    # Mesh 3 neighbours
    Enum.each(mesh3,fn (elem) ->
        a = Enum.find_index(mesh3, fn (b) -> b == elem end)
        cond do
          a == 0 ->
            upper_list = []
            lower_list = Enum.at(mesh3,1)
            front_list = Enum.at(mesh2,0)
            behind_list = Enum.at(mesh4,0)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
          a == last_index ->
            upper_list = Enum.at(mesh3,last_index - 1)
            lower_list = []
            front_list = Enum.at(mesh2,last_index)
            behind_list = Enum.at(mesh4,last_index)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
          true ->
            upper_list = Enum.at(mesh3,a - 1)
            lower_list = Enum.at(mesh3,a + 1)
            front_list = Enum.at(mesh2,a)
            behind_list = Enum.at(mesh4,a)
            send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index)
        end
    end)
  end

  def send_neighbour_outer3D(elem,upper_list,lower_list,behind_list,a,last_index) do
    Enum.each(elem, fn x ->
        pos = Enum.find_index(elem, fn (c) -> c == x end)
        cond do
          pos == 0 ->
            if a == 0 || a == last_index do
                list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(elem,(pos+1))]
                GenServer.call(x, {:pass_list, list})
            else
                list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos+1))]
                GenServer.call(x, {:pass_list, list})
            end
          pos == last_index ->
            if a == 0 || a == last_index do
                list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(elem,(pos-1))]
                GenServer.call(x, {:pass_list, list})
            else
                list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1))]
                GenServer.call(x, {:pass_list, list})
            end
          pos >0 && pos < last_index ->
            list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1)),Enum.at(elem,(pos+1))]
            list = Enum.reject(list,fn x -> x == nil end)
            GenServer.call(x, {:pass_list, list})
        end
    end)
  end

  def send_neighbour_inner3D(elem,upper_list,lower_list,front_list,behind_list,a,last_index) do
    Enum.each(elem, fn x ->
        pos = Enum.find_index(elem, fn (c) -> c == x end)
        cond do
          pos == 0 ->
            cond do
              a == 0 ->
                list = [Enum.at(front_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos+1))]
                GenServer.call(x, {:pass_list, list})
              a == last_index ->
                list = [Enum.at(front_list,pos),Enum.at(upper_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos+1))]
                GenServer.call(x, {:pass_list, list})
              true ->
                list = [Enum.at(upper_list,pos),Enum.at(front_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos+1))]
                GenServer.call(x, {:pass_list, list})
            end
          pos == last_index ->
            cond do
              a == 0 ->
                list = [Enum.at(front_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1))]
                GenServer.call(x, {:pass_list, list})
              a == last_index ->
                list = [Enum.at(front_list,pos),Enum.at(upper_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1))]
                GenServer.call(x, {:pass_list, list})
              true ->
                list = [Enum.at(upper_list,pos),Enum.at(front_list,pos),Enum.at(lower_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1))]
                GenServer.call(x, {:pass_list, list})
            end
          pos > 0 && pos < last_index ->
            list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(front_list,pos),Enum.at(behind_list,pos),Enum.at(elem,(pos-1)),Enum.at(elem,(pos+1))]
            list = Enum.reject(list,fn x -> x == nil end)
            GenServer.call(x, {:pass_list, list})
        end
    end)
  end

  def createTorus(nodes,x) do
    mesh = Enum.chunk_every(nodes,x)
    last_index = 4*x - 1
    Enum.each(mesh,fn (elem) ->
        a = Enum.find_index(mesh, fn (b) -> b == elem end)
        cond do
          a == 0 ->
            upper_list = Enum.at(mesh,last_index)
            lower_list = Enum.at(mesh,1)
            send_neighbour(elem,upper_list,lower_list,x)
          a == last_index ->
            upper_list = Enum.at(mesh,last_index - 1)
            lower_list = Enum.at(mesh,0)
            send_neighbour(elem,upper_list,lower_list,x)
          true ->
            upper_list = Enum.at(mesh,a - 1)
            lower_list = Enum.at(mesh,a + 1)
            send_neighbour(elem,upper_list,lower_list,x)
        end
    end)
  end

  def send_neighbour(list,upper_list,lower_list,y) do
    Enum.each(list, fn x ->
        pos = Enum.find_index(list, fn (c) -> c == x end)
        cond do
          pos == 0 ->
            list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(list,(y-1)),Enum.at(list,(pos+1))]
            GenServer.call(x, {:pass_list, list})
          pos == (y-1) ->
            list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(list,(pos-1)),Enum.at(list,0)]
            GenServer.call(x, {:pass_list, list})
          true ->
            list = [Enum.at(upper_list,pos),Enum.at(lower_list,pos),Enum.at(list,(pos-1)),Enum.at(list,(pos+1))]
            GenServer.call(x, {:pass_list, list})
        end
    end)
  end

  # Server API
   def handle_call({:pass_list, list}, _from, state) do
    {nodeID, count, _, w} = state
    state = {nodeID, count, list, w}
    # IO.inspect list
    {:reply, list, state}
  end

  def handle_call({:setState, x}, _from, state) do
    {_, count, arr, w} = state
    state = {x, count, arr, w}
    {:reply, x, state}
  end

  def handle_call({:updateCount, start, numNodes}, _from, state) do
    {nid, count, arr, w} = state
    if count == 0 do
      count = :ets.update_counter(:table, "count", {2, 1})
      if (count == numNodes) do
        algo_time = System.monotonic_time(:microsecond) - start
        IO.puts "Convergence time: #{algo_time} microseconds"
        System.halt(1)
      end
    end
    state = {nid, count+1, arr, w}
    {:reply, count+1, state}
  end

  def handle_call({:getNeighbours}, _from, state) do
    {_, _, list, _} = state
    {:reply, list, state}
  end

  def handle_call({:getCount}, _from, state) do
    {_, count, _, _} = state
    {:reply, count, state}
  end

  def handle_call({:random, new_arr}, _from, state) do
    {nid, count, [], w} = state
    state = {nid, count, new_arr, w}
    # IO.inspect new_arr
    {:reply, new_arr, state}
  end

  def handle_cast({:receivepushsum, s_in, w_in, start, numNodes},state) do
    {s, count, neighbours, w} = state
    new_s = s + s_in
    new_w = w + w_in
    diff = abs((new_s/new_w) - (s/w))
    # IO.puts diff
    if(diff < :math.pow(10,-10) && count==2) do
      t_count = :ets.update_counter(:table, "count", {2,1})
      if t_count == numNodes do
        algo_time = System.monotonic_time(:microsecond) - start
        IO.puts "Convergence time: " <> Integer.to_string(algo_time) <>" microseconds"
        System.halt(1)
      end
    end
    count =
      if (diff < :math.pow(10, -10) && count < 2) do
        count + 1
      else
        0
      end
    state = {new_s/2, count, neighbours, new_w/2}
    # IO.inspect(neighbours)
    random_node = Enum.random(neighbours)
    sendPushSum(random_node, new_s/2, new_w/2, start, numNodes)
    {:noreply, state}
  end
end

Project2.main(System.argv())
