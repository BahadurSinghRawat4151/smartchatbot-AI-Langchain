class CreateUserMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :user_memories do |t|
      t.string :session_id, null: false
      t.string :role,       null: false
      t.string :intent,     null: false
      t.text   :content,    null: false
      t.vector :embedding,  limit: 384

      t.timestamps
    end

    add_index :user_memories, :session_id
    add_index :user_memories,
              :embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: "index_user_memories_on_embedding"
  end
end
