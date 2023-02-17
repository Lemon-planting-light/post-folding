# frozen_string_literal: true

class FoldedPost < ActiveRecord::Base
  belongs_to :folded_by, class_name: :User, foreign_key: :folded_by_id

  def self.folded?(id)
    !self.find_by(id:)&.folded_by_id.nil?
  end

  def self.cooled_down?(id)
    data = self.find_by(id:)
    return true if data.nil?
    cd = data.folded_by_id.nil? ? SiteSetting.fold_post_cooldown : SiteSetting.unfold_post_cooldown
    Time.now >= data.changed_at + cd
  end

  def self.fold_post(id, folded_by_id)
    if self.exists?(id:)
      self.find_by(id:).update!(folded_by_id: folded_by_id, changed_at: Time.now)
    else
      self.create(id: id, folded_by_id: folded_by_id, changed_at: Time.now)
    end
  end
  def self.unfold_post(id)
    self.find_by(id:).update!(folded_by_id: nil, changed_at: Time.now) if self.folded?(id)
  end
end
