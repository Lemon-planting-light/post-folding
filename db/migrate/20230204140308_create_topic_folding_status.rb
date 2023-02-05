# frozen_string_literal: true

class CreateTopicFoldingStatus < ActiveRecord::Migration[7.0]
  def change
    create_table :topic_folding_status do |t|
      t.integer :enabled_by_id
    end
  end
end
