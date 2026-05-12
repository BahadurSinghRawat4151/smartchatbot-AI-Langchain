class ScopeMessagesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :messages, :user, foreign_key: true
  end
end
