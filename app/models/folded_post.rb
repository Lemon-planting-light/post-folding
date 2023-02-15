# frozen_string_literal: true

class FoldedPost < ActiveRecord::Base
  belongs_to :folded_by, class_name: :User, foreign_key: :folded_by_id

  def self.folded?(id)
    self.exists?(id:)
  end

  def self.fold_post(id, folded_by_id)
    self.create(id:, folded_by_id:) unless self.folded?(id)
  end
  def self.unfold_post(id)
    self.destroy_by(id:) if self.folded?(id)
  end
end