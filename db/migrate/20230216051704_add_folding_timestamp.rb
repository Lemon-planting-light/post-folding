# frozen_string_literal: true

class AddFoldingTimestamp < ActiveRecord::Migration[7.0]
  def change
    change_table :topic_folding_status do |t|
      t.datetime :changed_at, null: false, default: Time.new(1926, 8, 17)
    end
    change_table :folded_posts do |t|
      t.datetime :changed_at, null: false, default: Time.new(1926, 8, 17)
    end
  end
end
