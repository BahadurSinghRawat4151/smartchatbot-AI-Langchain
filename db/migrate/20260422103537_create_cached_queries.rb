class CreateCachedQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :cached_queries do |t|
      t.text    :query_text,      null: false
      t.vector  :query_embedding, limit: 384
      t.text    :ai_response,     null: false
      t.integer :product_ids,     array: true, default: []
      t.integer :hit_count,       default: 0

      t.timestamps
    end

    add_index :cached_queries,
              :query_embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: "index_cached_queries_on_embedding"
  end
end
