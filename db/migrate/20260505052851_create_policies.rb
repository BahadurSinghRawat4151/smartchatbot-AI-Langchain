class CreatePolicies < ActiveRecord::Migration[7.0]
  def change
    create_table :policies do |t|
      t.string :title, null: false
      t.string :category
      t.timestamps
    end

    add_index :policies, :title
  end
end
