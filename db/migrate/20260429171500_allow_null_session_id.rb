class AllowNullSessionId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :messages, :session_id, true
    # change_column_null :user_memories, :session_id, true
  end
end
