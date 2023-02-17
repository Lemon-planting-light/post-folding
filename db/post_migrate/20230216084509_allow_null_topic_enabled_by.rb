# frozen_string_literal: true

class AllowNullTopicEnabledBy < ActiveRecord::Migration[7.0]
  def change
    change_table :topic_folding_status do |t|
      t.change_null :enabled_by_id, true
    end
  end
end
