# frozen_string_literal: true

class PostFoldingsController < ::ApplicationController
  before_action :ensure_logged_in

  def toggle
    unless SiteSetting.post_folding_enabled
      response.status = 405
      render json: { succeed: false, message: I18n.t("post_foldings.not_enabled") }
      return
    end
    post = Post.find_by(id: params[:post])
    guardian.ensure_can_see_post!(post)
    if post.post_number == 1
      response.status = 400
      render json: { succeed: false, message: I18n.t("post_foldings.no_fold_first") }
      return
    end
    unless TopicFoldingStatus.enabled?(post.topic.id)
      response.status = 400
      render json: { succeed: false, message: I18n.t("post_foldings.not_enabled_in_topic") }
      return
    end
    if FoldedPost.folded?(post.id)
      with_perm guardian.can_unfold_post?(post) do
        FoldedPost.unfold_post(post.id)
        StaffActionLogger.new(guardian.user).log_custom(:fold_post, post_id: post.id)
        render json: { succeed: true, folded: true }
      end
    else
      with_perm guardian.can_fold_post?(post) do
        FoldedPost.fold_post(post.id, guardian.user.id)
        StaffActionLogger.new(guardian.user).log_custom(:unfold_post, post_id: post.id)
        render json: { succeed: true, folded: false }
      end
    end
  end

  def is_folding_enabled
    topic = Topic.find_by(id: params[:topic])
    guardian.ensure_can_see_topic!(topic)
    render json: { succeed: true, enabled: TopicFoldingStatus.enabled?(topic.id) }
  end

  def set_folding_enabled
    impl_set_folding_enabled params[:topic], params[:enabled]
  end

  def toggle_folding_enabled
    impl_set_folding_enabled params[:topic], !TopicFoldingStatus.enabled?(params[:topic])
  end

  private

  def impl_set_folding_enabled(id, en)
    topic = Topic.find_by(id:)
    guardian.ensure_can_see_topic!(topic)
    with_perm guardian.can_change_topic_post_folding?(topic) do
      if en
        TopicFoldingStatus.enable topic.id, guardian.user.id
        StaffActionLogger.new(guardian.user).log_custom(:enable_topic_post_folding, topic_id: id)
      else
        TopicFoldingStatus.disable topic.id
        StaffActionLogger.new(guardian.user).log_custom(:disable_topic_post_folding, topic_id: id)
      end
      render json: { succeed: true, enabled: TopicFoldingStatus.enabled?(id) }
    end
  end

  def with_perm(perm)
    if perm
      yield
    else
      response.status = 403
      render json: { succeed: false, message: I18n.t("post_foldings.no_perm") }
    end
  end
end
