# frozen_string_literal: true

class TopicFoldingStatus < ActiveRecord::Base
  self.table_name = "topic_folding_status"

  belongs_to :enabled_by, class_name: :User, foreign_key: :enabled_by_id

  def self.enabled?(id)
    self.exists?(id:)
  end

  def self.enable(id, en_id)
    self.create id: id, enabled_by_id: en_id unless self.enabled?(id)
  end
  def self.disable(id)
    self.destroy_by id: id if self.enabled?(id)
  end
end
