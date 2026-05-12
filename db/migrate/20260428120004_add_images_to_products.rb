class AddImagesToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :images, :text
  end
end
