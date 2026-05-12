class ChangeTagsToJsonb < ActiveRecord::Migration[8.1]
  def change
  remove_column :products, :tags
  add_column :products, :tags, :jsonb, default: []
end
end
