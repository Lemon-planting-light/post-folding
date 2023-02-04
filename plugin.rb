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
  load File.expand_path('../app/controllers/post_foldings_controller.rb', __FILE__)
  Discourse::Application.routes.append do
    post '/post_foldings' => 'post_foldings#toggle'
  end

  # Do the patch
  class ::TopicView
    private
    def setup_filtered_posts
      PostFolding.orig_setup_filtered_posts.bind(self).call
      if SiteSetting.post_folding_enabled
        # TODO: add topics containing folded posts to DB, to have better condition (though not quite optimizing)
        @contains_gaps = true
        @filtered_posts = @filtered_posts.where('posts.id NOT IN (SELECT fd.id FROM posts_folded fd)')
      end
    end
  end

  class ::Guardian
    def can_fold_post?(post)
      is_my_own?(post) || user.in_any_groups(SiteSetting.post_folding_manipulatable_groups_map)
    end
    def can_unfold_post?(post, folded_by)
      return true if user.in_any_groups(SiteSetting.post_folding_manipulatable_groups_map)
      is_my_own?(post) && folded_by == post.user.id
    end
  end
end
