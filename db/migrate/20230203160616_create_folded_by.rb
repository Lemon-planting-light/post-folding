# frozen_string_literal: true

class CreateFoldedBy < ActiveRecord::Migration[7.0]
  def change
    create_table :posts_folded do |t|
      t.integer :folded_by_id, null: true
    end
  end
end
