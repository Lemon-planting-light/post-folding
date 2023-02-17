# frozen_string_literal: true

# name: post-folding
# about: A plugin adding support of manually folding a post
# version: 0.1.1
# authors: Virginia Senioria, Linca
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

  %i[BYPASS_CD WAIT_FOR_CD CD_ENDED NO_PERMISSION].each do |name|
    self.define_singleton_method(name) { name.to_s }
  end
end

after_initialize do
  %w[
    app/controllers/post_foldings_controller.rb
    app/models/topic_folding_status.rb
    app/models/folded_post.rb
  ].each { |f| load File.expand_path("../#{f}", __FILE__) }

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
          @contains_gaps = true
          @filtered_posts =
            @filtered_posts.where(
              "posts.id NOT IN (SELECT fd.id FROM folded_posts fd WHERE fd.folded_by_id IS NOT NULL)",
            )
        end
      end
    end

    class ::Group
      scope :can_manipulate_post_foldings, ->(user) { user.can_manipulate_post_foldings? }
    end
  end

  add_to_class(:guardian, :toggle_post_folding_perm) do |post|
    return PostFolding.NO_PERMISSION if post.locked? && !is_staff?
    return PostFolding.NO_PERMISSION if user&.banned_for_post_foldings?
    return PostFolding.BYPASS_CD if user&.can_manipulate_post_foldings? || is_staff?
    return PostFolding.NO_PERMISSION unless is_my_own?(post) && can_edit?(post)
    info = FoldedPost.find_by(id: post.id)
    return PostFolding.NO_PERMISSION unless info&.folded_by_id.nil? || post.user.id == info.folded_by_id
    FoldedPost.cooled_down?(post.id) ? PostFolding.CD_ENDED : PostFolding.WAIT_FOR_CD
  end
  add_to_class(:guardian, :can_toggle_post_folding?) do |post|
    [PostFolding.BYPASS_CD, PostFolding.CD_ENDED].include?(toggle_post_folding_perm(post))
  end
  add_to_class(:guardian, :change_topic_post_folding_perm) do |topic|
    return PostFolding.NO_PERMISSION if user&.banned_for_post_foldings?
    return PostFolding.BYPASS_CD if user&.can_manipulate_post_foldings?
    return PostFolding.NO_PERMISSION if topic.archived?
    return PostFolding.NO_PERMISSION unless is_my_own?(topic) && can_edit?(topic) && topic.folding_capable?
    info = TopicFoldingStatus.find_by(id: topic.id)
    return PostFolding.NO_PERMISSION unless info&.enabled_by_id.nil? || user.id == info.enabled_by_id
    TopicFoldingStatus.cooled_down?(topic.id) ? PostFolding.CD_ENDED : PostFolding.WAIT_FOR_CD
  end
  add_to_class(:guardian, :can_change_topic_post_folding?) do |topic|
    [PostFolding.BYPASS_CD, PostFolding.CD_ENDED].include?(change_topic_post_folding_perm(topic))
  end

  add_to_serializer(:current_user, :can_manipulate_post_foldings) { user.can_manipulate_post_foldings? }
  add_to_class(:user, :can_manipulate_post_foldings?) do
    in_any_groups?(SiteSetting.post_folding_manipulatable_groups_map)
  end
  add_to_serializer(:current_user, :is_banned_for_post_foldings) { user.banned_for_post_foldings? }
  add_to_class(:user, :banned_for_post_foldings?) do
    return true if SiteSetting.post_folding_banned_users.to_s.split("|").include?(username)
    !in_any_groups?(SiteSetting.post_folding_allowed_groups_map) && !can_manipulate_post_foldings?
  end

  add_to_class(:topic, :folding_enabled_by) do
    return @folding_enabled_by[0] if @folding_enabled_by
    @folding_enabled_by = [TopicFoldingStatus.find_by(id:)&.enabled_by]
    @folding_enabled_by[0]
  end
  add_to_class(:topic, :folding_capable?) do
    return true if SiteSetting.all_topics_post_folding_capable
    return @folding_capable if @folding_capable
    @folding_capable =
      SiteSetting.post_folding_capable_categories.to_s.split("|").map(&:to_i).include?(category.id) ||
        SiteSetting.post_folding_capable_tags.to_s.split("|").intersect?(tags.map(&:name))
  end

  add_to_serializer(:post, :folded_by) do
    BasicUserSerializer.new(FoldedPost.find_by(id:)&.folded_by, root: false).as_json
  end

  add_to_serializer(:post, :toggle_post_folding_perm) { scope.toggle_post_folding_perm(object) }
  add_to_serializer(:post, :can_toggle_post_folding) { scope.can_toggle_post_folding?(object) }
  add_to_serializer(:post, :folded_changed_at) { FoldedPost.find_by(id: object.id)&.changed_at }
  add_to_serializer(:post, :in_folding_enabled_topic) { !@topic.folding_enabled_by.nil? }
  add_to_serializer(:topic_view, :folding_enabled_by) do
    BasicUserSerializer.new(topic.folding_enabled_by, root: false).as_json
  end
  add_to_serializer(:post, :folding_enabled_changed_at) { TopicFoldingStatus.find_by(id: @topic.id)&.changed_at }
  add_to_serializer(:post, :in_folding_capable_topic) { @topic.folding_capable? }
  add_to_serializer(:post, :change_topic_post_folding_perm) { scope.change_topic_post_folding_perm(@topic) }
  add_to_serializer(:post, :can_change_topic_post_folding) { scope.can_change_topic_post_folding?(@topic) }
  add_to_serializer(:topic_view, :folding_capable) { topic.folding_capable? }
end
