import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";
// import { iconNode } from "discourse-common/lib/icon-library";
// import I18n from "I18n";
// import DiscourseURL from "discourse/lib/url";

const pluginId = "post-folding";

function init(api) {

  api.modifyClass("model:post-stream", {
    pluginId,

    unfoldForAll() {
      this.cancelFilter();
      this.set("filter", "unfold_all");
      return this.refreshAndJumpToSecondVisible();
    },

    enfoldForAll() {
      this.cancelFilter();
      return this.refreshAndJumpToSecondVisible();
    },
  });

  api.reopenWidget("post", {
    toggleUnfoldAll() {
      if (this._topicController().filter) {
        this._topicController()
        .model.postStream.enfoldForAll()
        .then(() => {
          this._refreshController();
        });
      } else {
        this._topicController()
        .model.postStream.unfoldForAll()
        .then(() => {
          this._refreshController();
        });
      }

    },

    _refreshController() {
      this._topicController().updateQueryParams();
      this._topicController().appEvents.trigger("post-folding-topic-updated");
    },

    _topicController() {
      return this.register.lookup("controller:topic");
    },
  });

  api.decorateWidget("post-contents:after-cooked", helper => {
    if (helper?.getModel()?.post_number !== 1) { return; }
    function _topicController() {
      return helper.register.lookup("controller:topic");
    }
    // TODO: Add I18n support
    return helper.h("div.post-folding-tip", [
      helper.h("hr"),
      helper.h("p", "本主题开启了帖子折叠功能。"),
      helper.attach("button", {
        action: "toggleUnfoldAll",
        contents: _topicController().filter ? "点此折叠所有被展开的帖子" : "点此展开所有被折叠的帖子",
        className: `btn btn-link btn-post-unfold-all`,
      }),
    ]);
  });

  api.includePostAttributes(
    "folded_by"
  );

  api.addPostClassesCallback((attrs) => {
    // Not folded
    if (attrs.folded_by === null) {
      return [];
    } else {
      if (attrs.folded_by === curUser.id) {
        return ["folded", "folded-by-me"];
      } else {
        return ["folded", "folded-by-others"];
      }
    }
  });

  const curUser = api.getCurrentUser();

  if (!curUser) { return; }

  api.addPostMenuButton("toggle-folding", (post) => {
    if (post.user.id !== curUser.id && !curUser.can_manipulate_post_foldings) {
      return;
    }
    if (post.post_number === 1 || post.deleted_at) {
      return;
    }
    if (post.folded_by) {
      if (!curUser.can_manipulate_post_foldings && post.folded_by !== curUser.id) {
        return {
          action: "toggleFolding",
          icon: "expand",
          title: "post_folding.toggle_folding", // TODO: add new title post_folding.toggle_folding_unavailable
          position: "second-last-hidden",
          className: "toggle-folding",
          disabled: "true"
        };
      } else {
        return {
          action: "toggleFolding",
          icon: "expand",
          title: "post_folding.toggle_folding",
          position: "second-last-hidden",
          className: "toggle-folding",
        };
      }
    } else {
      return {
        action: "toggleFolding",
        icon: "compress",
        title: "post_folding.toggle_folding",
        position: "second-last-hidden",
        className: "toggle-folding",
      };
    }
  });

  // Arrow functions won't take this, so use functions
  api.attachWidgetAction("post", "toggleFolding", function () {
    const post = this.model;
    ajax("/post_foldings", {
      method: "POST",
      data: { post: post.id },
    })
      .then((res) => {
        if (!res.succeed) {
          getOwner(this).lookup("service:dialog").alert(res.message);
          return;
        } else {
          if (post.folded_by) {
            post.setProperties({
              folded_by: null,
            });
          } else {
            post.setProperties({
              folded_by: this.currentUser.id,
            });
          }
          this.appEvents.trigger("post-stream:refresh", {
            id: post.id,
          });
          this.appEvents.trigger("header:update-topic", post);
        }
      })
      .catch(popupAjaxError);
  });
}

export default {
  name: pluginId,

  initialize(container) {
    if (!container.lookup("site-settings:main").post_folding_enabled) {
      return;
    }
    withPluginApi("1.6.0", init);
  },
};
