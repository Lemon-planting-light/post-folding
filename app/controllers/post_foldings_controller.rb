# frozen_string_literal: true

class PostFoldingsController < ::ApplicationController
  before_action :ensure_logged_in

  def toggle
    unless SiteSetting.post_folding_enabled
      render json: { succeed: false, message: I18n.t("post_foldings.not_enabled") }
      return
    end
    post = Post.find_by(id: params[:post])
    if post.post_number == 1
      response.status = 400
      render json: { succeed: false, message: I18n.t("post_foldings.no_fold_first") }
      return
    end
    info = DB.query_single("SELECT folded_by_id FROM posts_folded fd WHERE fd.id = ?", post.id)
    if info.empty?
      with_perm guardian.can_fold_post?(post) do
        DB.exec "INSERT INTO posts_folded VALUES (?, ?);", post.id, guardian.user.id
        render json: { succeed: true, folded: true }
      end
    else
      with_perm guardian.can_unfold_post?(post, info[0]) do
        DB.exec "DELETE FROM posts_folded fd WHERE fd.id = ?", post.id
        render json: { succeed: true, folded: false }
      end
    end
  end

  private

  def with_perm(perm, &block)
    if perm
      block.call
    else
      response.status = 403
      render json: { succeed: false, message: I18n.t("post_foldings.no_perm") }
    end
  end
end
