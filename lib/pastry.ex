defmodule Pastry do
  @moduledoc """
  Documentation for Pastry.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Pastry.hello
      :world

  """
  def hello do
    :world
  end

  def main(args) do
      cond do
        length(args)!= 2 ->
          IO.puts "Number of arguments do not match"
          Utility.print_valid_format_info()
        Utility.isInteger(List.first(args)) == false or Utility.isInteger(List.last(args)) == false or 
            String.to_integer(List.first(args)) < 2 or String.to_integer(List.last(args)) < 1 ->
          IO.puts "Parameters should be Integer. numNodes should be greater than 2 and numRequests greater than 1"
        true ->
          [numNodesStr, numRequestsStr] = args
          numNodes = String.to_integer(numNodesStr)
          numRequests = String.to_integer(numRequestsStr)
          state = %{total_nodes: numNodes, total_requests: numRequests, main_pid: self()}
          Manager.start_process(state)
          receive do
            _ -> 
              IO.puts "End"
          end #receive end
      end  #cond end
  end #main end

end #defmodule end
