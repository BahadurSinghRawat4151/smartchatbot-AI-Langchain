class CreatePolicyChunks < ActiveRecord::Migration[7.0]
  def change
    create_table :policy_chunks do |t|
      t.references :policy, null: false, foreign_key: true

      t.text :content, null: false
      t.integer :chunk_index

      # 🔥 vector column (important)
      t.vector :embedding, limit: 384

      t.timestamps
    end

    # 🔥 pgvector index for fast similarity search
    #   add_index :policy_chunks, :embedding,
    #     using: :ivfflat,
    #     opclass: :vector_cosine_ops,
    #     options: "WITH (lists = 100)"
  end
end
