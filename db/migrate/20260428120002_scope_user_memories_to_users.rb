class ScopeUserMemoriesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_memories, :user, foreign_key: true
    change_column_null :user_memories, :session_id, true
    remove_index :user_memories, :session_id
  end
end
