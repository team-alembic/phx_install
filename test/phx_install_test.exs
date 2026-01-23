defmodule PhxInstallTest do
  use ExUnit.Case

  describe "version/0" do
    test "returns the current version" do
      assert PhxInstall.version() == "0.1.0"
    end
  end

  describe "random_string/1" do
    test "generates a string of the specified length" do
      assert String.length(PhxInstall.random_string(8)) == 8
      assert String.length(PhxInstall.random_string(32)) == 32
      assert String.length(PhxInstall.random_string(64)) == 64
    end

    test "generates different strings each time" do
      refute PhxInstall.random_string(32) == PhxInstall.random_string(32)
    end
  end
end
