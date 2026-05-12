class AddTagsAndProductTypeToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :tags, :string, array: true, default: []
    add_column :products, :product_type, :string
  end
end
