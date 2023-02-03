# frozen_string_literal: true

class PostFoldingsController < ::ApplicationController
  before_action :ensure_logged_in

  def toggle
    post = Post.find_by(id: params[:post])
    info = DB.query_single('SELECT folded_by_id FROM posts_folded fd WHERE fd.id = ?', post.id)
    if info.empty?
      with_perm guardian.can_fold_post?(post) do
        DB.exec 'INSERT INTO posts_folded VALUES (?, ?);', post.id, guardian.user.id
        render json: { succeed: true, folded: true }
      end
    else
      with_perm guardian.can_unfold_post?(post, info[0]) do
        DB.exec 'DELETE FROM posts_folded fd WHERE fd.id = ?', post.id
        render json: { succeed: true, folded: false }
      end
    end
  end

  private

  def with_perm(perm, &block)
    if perm
      block.call
    else
      render json: { succeed: false, message: I18n.t('post_foldings.no_perm') }
    end
  end
end
