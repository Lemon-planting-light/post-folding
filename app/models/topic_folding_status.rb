# frozen_string_literal: true

class TopicFoldingStatus < ActiveRecord::Base
  self.table_name = "topic_folding_status"

  belongs_to :enabled_by, class_name: :User, foreign_key: :enabled_by_id

  def self.enabled?(id)
    !self.find_by(id:)&.enabled_by_id.nil?
  end

  def self.cooled_down?(id)
    data = self.find_by(id:)
    return true if data.nil?
    cd =
      (
        if data.enabled_by_id.nil?
          SiteSetting.topic_enable_post_folding_dooldown
        else
          SiteSetting.topic_disable_post_folding_cooldown
        end
      )
    Time.now >= data.changed_at + cd
  end

  def self.enable(id, enabled_by_id)
    if self.exists?(id:)
      self.find_by(id:).update!(enabled_by_id: enabled_by_id, changed_at: Time.now)
    else
      self.create(id: id, enabled_by_id: enabled_by_id, changed_at: Time.now)
    end
  end
  def self.disable(id)
    self.find_by(id:).update!(enabled_by_id: nil, changed_at: Time.now) if self.enabled?(id)
  end
end
