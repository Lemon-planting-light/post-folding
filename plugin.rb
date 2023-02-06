# frozen_string_literal: true

# name: post-folding
# about: A plugin adding support of manually folding a post
# version: 0.0.1
# authors: Virginia Senioria
# url: https://github.com/Lemon-planting-light/post-folding
# required_version: 3.0.0

enabled_site_setting :post_folding_enabled

register_asset "stylesheets/post_folding.scss"
if respond_to?(:register_svg_icon)
  register_svg_icon "expand"
  register_svg_icon "compress"
  register_svg_icon "toggle-off"
  register_svg_icon "toggle-on"
end

module ::PostFolding
  def self.init
    @@orig_setup_filtered_posts = ::TopicView.instance_method(:setup_filtered_posts)
  end
  def self.orig_setup_filtered_posts
    @@orig_setup_filtered_posts
  end
end

after_initialize do
  load File.expand_path("../app/controllers/post_foldings_controller.rb", __FILE__)
  load File.expand_path("../app/models/topic_folding_status.rb", __FILE__)

  Discourse::Application.routes.append do
    post "/post_foldings" => "post_foldings#toggle"
    get "/post_foldings/is_folding_enabled" => "post_foldings#is_folding_enabled"
    put "/post_foldings/set_folding_enabled" => "post_foldings#set_folding_enabled"
    post "/post_foldings/toggle_folding_enabled" => "post_foldings#toggle_folding_enabled"
  end

  reloadable_patch do |plugin|
    PostFolding.init

    class ::TopicView
      private

      def setup_filtered_posts
        PostFolding.orig_setup_filtered_posts.bind(self).call
        if SiteSetting.post_folding_enabled && @filter.to_s != "unfold_all" && TopicFoldingStatus.enabled?(@topic.id)
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
    return true if user&.can_manipulate_post_foldings?
    is_my_own?(post)
  end
  add_to_class(:guardian, :can_unfold_post?) do |post, folded_by|
    return true if user&.can_manipulate_post_foldings?
    is_my_own?(post) && folded_by == post.user.id
  end
  add_to_class(:guardian, :can_change_topic_post_folding?) do |topic|
    return true if user&.can_manipulate_post_foldings?
    return false unless is_my_own?(topic)
    return false unless topic.folding_capable?
    info = TopicFoldingStatus.find_by(id: topic.id)
    !info || info.enabled_by_id == user.id
  end

  add_to_serializer(:current_user, :can_manipulate_post_foldings) { user.can_manipulate_post_foldings? }
  add_to_class(:user, :can_manipulate_post_foldings?) do
    in_any_groups?(SiteSetting.post_folding_manipulatable_groups_map)
  end

  add_to_class(:topic, :folding_enabled_by) do
    return @folding_enabled_by[0] if @folding_enabled_by
    @folding_enabled_by = [TopicFoldingStatus.find_by(id:)&.enabled_by_id]
    @folding_enabled_by[0]
  end
  add_to_class(:topic, :folding_capable?) do
    return true if SiteSetting.all_topics_post_folding_capable
    SiteSetting.post_folding_capable_categories.to_s.split("|").map(&:to_i).include?(category.id) ||
      SiteSetting.post_folding_capable_tags.to_s.split("|").intersect?(tags.map(&:name))
  end

  add_to_serializer(:post, :folded_by) do
    DB.query_single("SELECT folded_by_id FROM posts_folded fd WHERE fd.id = ?", id)[0]
  end

  add_to_serializer(:post, :in_folding_enabled_topic) { !@topic.folding_enabled_by.nil? }
  add_to_serializer(:topic_view, :folding_enabled_by) { topic.folding_enabled_by }
  add_to_serializer(:post, :in_folding_capable_topic) { @topic.folding_capable? }
  add_to_serializer(:topic_view, :folding_capable) { topic.folding_capable? }
end
