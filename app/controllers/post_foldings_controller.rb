# frozen_string_literal: true

class PostFoldingsController < ::ApplicationController
  before_action :ensure_logged_in

  def toggle
    return render_fail "post_foldings.not_enabled", status: 405 unless SiteSetting.post_folding_enabled
    post = Post.find_by(id: params[:post])
    guardian.ensure_can_see_post!(post)
    return render_fail "post_foldings.no_fold_first" if post.post_number == 1
    return render_fail "post_foldings.not_enabled_in_topic" unless TopicFoldingStatus.enabled?(post.topic.id)
    if FoldedPost.folded?(post.id)
      unless guardian.can_unfold_post?(post)
        return render_fail "post_foldings.not_cooled_down", status: 403 unless FoldedPost.cooled_down?(post.id)
        return render_fail "post_foldings.no_perm", status: 403
      end
      FoldedPost.unfold_post(post.id)
      StaffActionLogger.new(guardian.user).log_custom(:fold_post, post_id: post.id)
      render json: { succeed: true, folded: true }
    else
      unless guardian.can_fold_post?(post)
        return render_fail "post_foldings.not_cooled_down", status: 403 unless FoldedPost.cooled_down?(post.id)
        return render_fail "post_foldings.no_perm", status: 403
      end
      FoldedPost.fold_post(post.id, guardian.user.id)
      StaffActionLogger.new(guardian.user).log_custom(:unfold_post, post_id: post.id)
      render json: { succeed: true, folded: false }
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
    unless guardian.can_change_topic_post_folding?(topic)
      return render_fail "post_foldings.not_cooled_down", status: 403 unless TopicFoldingStatus.cooled_down?(topic.id)
      return render_fail "post_foldings.no_perm", status: 403
    end
    if en
      TopicFoldingStatus.enable topic.id, guardian.user.id
      StaffActionLogger.new(guardian.user).log_custom(:enable_topic_post_folding, topic_id: id)
    else
      TopicFoldingStatus.disable topic.id
      StaffActionLogger.new(guardian.user).log_custom(:disable_topic_post_folding, topic_id: id)
    end
    render json: { succeed: true, enabled: TopicFoldingStatus.enabled?(id) }
  end

  def render_fail(*args, **kwargs)
    response.status = kwargs[:status] || 400
    render json: { succeed: false, message: I18n.t(*args, **kwargs.except(:status)) }
    nil
  end

  def with_perm(perm)
    if perm
      yield
    else
      render_fail "post_foldings.no_perm", status: 403
    end
  end
end
