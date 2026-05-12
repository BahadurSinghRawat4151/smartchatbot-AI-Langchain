class DropUnusedHeavyAiTables < ActiveRecord::Migration[7.1]
  def up
    drop_table :cached_queries, if_exists: true
    drop_table :user_memories, if_exists: true
  end

  def down
    # Not reversing table drops back
  end
end
