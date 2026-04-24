class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string  :name,           null: false
      t.text    :description
      t.decimal :price,          precision: 10, scale: 2
      t.string  :category
      t.string  :brand
      t.jsonb   :specifications, default: {}
      t.integer :stock,          default: 0
      t.vector  :embedding,      limit: 384

      t.timestamps
    end

    add_index :products,
              :embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: "index_products_on_embedding"
  end
end
