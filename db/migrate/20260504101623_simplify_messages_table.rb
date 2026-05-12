class SimplifyMessagesTable < ActiveRecord::Migration[7.0]
  def change
    # Remove unwanted columns
    remove_column :messages, :content, :text
    remove_column :messages, :role, :string
    remove_column :messages, :session_id, :string
    remove_column :messages, :created_at, :datetime
    remove_column :messages, :updated_at, :datetime

    # Add new column
    add_column :messages, :ai_summary, :text
  end
end
