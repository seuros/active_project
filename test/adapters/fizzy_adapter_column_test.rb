# frozen_string_literal: true

require_relative "fizzy_adapter_base_test"

class FizzyAdapterColumnTest < FizzyAdapterBaseTest
  # --- list_lists (columns) ---
  test "list_lists returns an array of columns" do
    VCR.use_cassette("fizzy/list_columns") do
      columns = @adapter.list_lists(@board_id)
      assert_kind_of Array, columns
      # May or may not have columns depending on test data
    end
  end

  # --- create_list ---
  test "create_list creates a new column on a board" do
    VCR.use_cassette("fizzy/create_column") do
      column = @adapter.create_list(@board_id, name: "Test Column #{TIMESTAMP_PLACEHOLDER}")
      assert_kind_of Hash, column
      assert_not_nil column[:id]
      assert column[:name].start_with?("Test Column")
    end
  end

  test "create_list with color" do
    VCR.use_cassette("fizzy/create_column_with_color") do
      column = @adapter.create_list(@board_id,
                                    name: "Green Column",
                                    color: "var(--color-card-4)")
      assert_kind_of Hash, column
      assert_not_nil column[:id]
      assert_equal "Green Column", column[:name]
    end
  end

  test "create_list raises ArgumentError without name" do
    assert_raises ArgumentError do
      @adapter.create_list(@board_id, {})
    end
  end

  # --- find_list ---
  test "find_list returns a specific column" do
    VCR.use_cassette("fizzy/find_column") do
      # First create a column
      created = @adapter.create_list(@board_id, name: "Column to Find #{TIMESTAMP_PLACEHOLDER}")
      column_id = created[:id]

      # Then find it
      column = @adapter.find_list(@board_id, column_id)
      assert_kind_of Hash, column
      assert_equal column_id, column[:id]
    end
  end

  # --- update_list ---
  test "update_list updates a column name" do
    VCR.use_cassette("fizzy/update_column") do
      # First create a column
      created = @adapter.create_list(@board_id, name: "Original Column Name")
      column_id = created[:id]

      # Then update it
      updated_name = "Updated Column Name #{TIMESTAMP_PLACEHOLDER}"
      column = @adapter.update_list(@board_id, column_id, name: updated_name)
      assert_kind_of Hash, column
      assert_equal updated_name, column[:name]
    end
  end

  # --- delete_list ---
  test "delete_list deletes a column" do
    VCR.use_cassette("fizzy/delete_column") do
      # First create a column
      created = @adapter.create_list(@board_id, name: "Column to Delete #{TIMESTAMP_PLACEHOLDER}")
      column_id = created[:id]

      # Then delete it
      result = @adapter.delete_list(@board_id, column_id)
      assert_equal true, result
    end
  end
end
