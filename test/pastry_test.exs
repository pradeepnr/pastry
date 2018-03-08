defmodule PastryTest do
  use ExUnit.Case
  doctest Pastry

  test "greets the world" do
    assert Pastry.hello() == :world
  end

  test "check md5" do
    assert "6466F056D2E2A8E6EEEA9E6BF34735FF" == Utility.get_hash("node0")
  end

  test "test mismatch index" do
    assert 4 == Utility.get_mismatch_index("prad112", "prad001")
  end

  test "test no mismatch index" do
    assert 7 == Utility.get_mismatch_index("pradeep", "pradeep")
  end

  test "test no match index" do
    assert 0 == Utility.get_mismatch_index("pradeep", "bradeep")
  end

  test "test get closer hash" do
    assert "AE" == Utility.get_closer_hash("AA", "AE", "CB")
    assert "AE" == Utility.get_closer_hash("AA", "CB", "AE")
    assert "CB" == Utility.get_closer_hash("AA", "CB", "CE")
    assert "CB" == Utility.get_closer_hash("AA", "CE", "CB")
    assert "CB" == Utility.get_closer_hash("CA", "CE", "CB")
    assert "CE" == Utility.get_closer_hash("FA", "CE", "CB")
    assert "CB" == Utility.get_closer_hash("FA", "CB", "AA")
    assert "CB" == Utility.get_closer_hash("CB", "CB", "AA")
    assert "CB" == Utility.get_closer_hash("CB", "AA", "CB")
  end

  test "test update row" do
    currHash = "AA"
    currRow = %{"0"=>"AB", "2"=>"BC", "3"=>"FF"}
    newRow = %{"0"=>"AC", "2"=>"BA", "4"=>"42"}
    assert %{"0"=>"AB", "2"=>"BA", "3"=>"FF","4"=>"42"} == Utility.update_row(currHash, currRow, newRow)
  end

  test "test remove curr hash from table" do
    currHash = "AA"
    misMatchPos = 1
    newRoutingTable = %{0=>%{"0"=>"AC", "2"=>"BA", "4"=>"42"}, 1=>%{"0"=>"AC", "2"=>"BA", "4"=>"42", "A"=>"AA"}}
    assert %{0=>%{"0"=>"AC", "2"=>"BA", "4"=>"42"}, 1=>%{"0"=>"AC", "2"=>"BA", "4"=>"42"}} == Utility.remove_hash_from_table(currHash, misMatchPos, newRoutingTable)
  end

  test "test is_hash_with_in_leaf_set_Range" do
    assert false == Utility.is_hash_with_in_leaf_set_Range("AB", "BC", {[], []})
    assert true == Utility.is_hash_with_in_leaf_set_Range("AB", "AB", {[], []})

    assert true == Utility.is_hash_with_in_leaf_set_Range("AC", "AA", {[], ["FF"]})
    assert true == Utility.is_hash_with_in_leaf_set_Range("AC", "AA", {[], ["FF","FC"]})
    assert false == Utility.is_hash_with_in_leaf_set_Range("12", "AA", {[], ["FF","FC"]})

    assert true == Utility.is_hash_with_in_leaf_set_Range("AA", "AC", {["12"], []})
    assert true == Utility.is_hash_with_in_leaf_set_Range("AA", "AC", {["34","FC"], []})
    assert false == Utility.is_hash_with_in_leaf_set_Range("FF", "AA", {["34","12"], []})

    assert true == Utility.is_hash_with_in_leaf_set_Range("AA", "AC", {["34","55"], ["FF","FB"]})
    assert false == Utility.is_hash_with_in_leaf_set_Range("10", "9A", {["34","42"], ["AB", "AA"]})
  end

  test "test update_leaf_set" do
    assert {["34", "42","99"], ["AC", "AB"]} == Utility.update_leaf_set("AA", {["34","42"], ["AC", "AB"]}, "99")
    assert {["34","42"], ["FF", "EF", "BB"]} == Utility.update_leaf_set("AA", {["34","42"], ["FF", "EF"]}, "BB")

    assert {["99"], ["AC", "AB"]} == Utility.update_leaf_set("AA", {[], ["AC", "AB"]}, "99")
    assert {["99"], ["FF"]} == Utility.update_leaf_set("AA", {["99"], []}, "FF")

    assert {[], ["FF"]} == Utility.update_leaf_set("AA", {[], []}, "FF")
    assert {[], ["AB"]} == Utility.update_leaf_set("AA", {[], []}, "AB")

    assert {["34","42"], ["BC","BB","BA","AF", "AE", "AD","AC", "AB"]} == Utility.update_leaf_set("AA", {["34","42"], ["BD","BC","BB","BA","AF", "AE", "AD","AC"]}, "AB")
    assert {["12","13","14","15","16","17","18","19"], ["FF", "EF"]} == Utility.update_leaf_set("AA", {["11","12","13","14","15","16","17","18"], ["FF", "EF"]}, "19")

    assert {["11","12","13","14","15","16","17","18"], ["FF", "EF"]} == Utility.update_leaf_set("AA", {["11","12","13","14","15","16","17","18"], ["FF", "EF"]}, "01")
    assert {["34","42"], ["BD","BC","BB","BA","AF", "AE", "AD","AC"]} == Utility.update_leaf_set("AA", {["34","42"], ["BD","BC","BB","BA","AF", "AE", "AD","AC"]}, "FF")
  end

  test "test get_nearest_node" do
    assert "AC" == Utility.get_nearest_node("AD", "AA", {["34","42"], ["AB", "AC", "FF", "EF"]}, %{0=>%{}})
    assert "AA" == Utility.get_nearest_node("AD", "AA", {[], []}, %{0=>%{}})
  end

  test "test add_hash_to_routing_table" do
    expectedHash = %{0=>%{"A"=>"AB"}}
    assert expectedHash == Utility.add_hash_to_routing_table("BC", %{}, "AB")

    expectedHash = %{0=>%{"A"=>"AB","B"=>"EF"}}
    assert expectedHash == Utility.add_hash_to_routing_table("BC", %{0=>%{"B"=>"EF"}}, "AB")

    expectedHash = %{0=>%{"A"=>"AB","B"=>"EF"}}
    assert expectedHash == Utility.add_hash_to_routing_table("BC", %{0=>%{"B"=>"EF", "A"=>"AA"}}, "AB")
  end
end
