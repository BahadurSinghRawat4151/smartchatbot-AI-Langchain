# db/migrate/xxx_remove_session_id_from_user_memories.rb

class RemoveSessionIdFromUserMemories < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_memories, :session_id if column_exists?(:user_memories, :session_id)
  end
end
