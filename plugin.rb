# frozen_string_literal: true

# name: post-folding
# about: A plugin adding support of manually folding a post
# version: 0.0.1
# authors: Virginia Senioria
# url: https://github.com/Lemon-planting-light/post-folding
# required_version: 3.0.0

enabled_site_setting :post_folding_enabled

module ::PostFolding
  def self.init
    @@orig_setup_filtered_posts = ::TopicView.instance_method(:setup_filtered_posts)
  end
  def self.orig_setup_filtered_posts
    @@orig_setup_filtered_posts
  end
end

after_initialize do
  PostFolding.init
  load File.expand_path("../app/controllers/post_foldings_controller.rb", __FILE__)

  # stree-ignore
  Discourse::Application.routes.append do
    post "/post_foldings" => "post_foldings#toggle"
  end

  reloadable_patch do |plugin|
    class ::TopicView
      private

      def setup_filtered_posts
        PostFolding.orig_setup_filtered_posts.bind(self).call
        if SiteSetting.post_folding_enabled && @filter.to_s != "unfold_all"
          # TODO: add topics containing folded posts to DB, to have better condition (though not quite optimizing)
          @contains_gaps = true
          @filtered_posts = @filtered_posts.where("posts.id NOT IN (SELECT fd.id FROM posts_folded fd)")
        end
      end
    end

    class ::Group
      scope :can_manipulate_post_foldings, ->(user) { user.can_manipulate_post_foldings? }
    end
  end

  add_to_class(:guardian, :can_fold_post?) do |post|
    return true if user && user.can_manipulate_post_foldings?
    is_my_own?(post)
  end
  add_to_class(:guardian, :can_unfold_post?) do |post, folded_by|
    return true if user && user.can_manipulate_post_foldings?
    is_my_own?(post) && folded_by == post.user.id
  end

  # stree-ignore
  add_to_serializer(:current_user, :can_manipulate_post_foldings) do
    user.can_manipulate_post_foldings?
  end
  add_to_class(:user, :can_manipulate_post_foldings?) do
    in_any_groups?(SiteSetting.post_folding_manipulatable_groups_map)
  end

  add_to_serializer(:post, :is_folded) do
    return @is_folded[0] if @is_folded
    @is_folded = [!DB.query_single("SELECT folded_by_id FROM posts_folded fd WHERE fd.id = ?", id).empty?]
    @is_folded[0]
  end
end
