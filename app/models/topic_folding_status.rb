# frozen_string_literal: true

class TopicFoldingStatus < ActiveRecord::Base
  self.table_name = "topic_folding_status"

  def self.enabled?(id)
    self.find_by(id:) != nil
  end

  def self.enable(id, en_id)
    self.create id: id, enabled_by_id: en_id unless self.enabled?(id)
  end
  def self.disable(id)
    self.destroy_by id: id if self.enabled?(id)
  end
end
