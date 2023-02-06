import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";
import I18n from "I18n";

const pluginId = "post-folding";

function init(api) {
  api.modifyClass("model:post-stream", {
    pluginId,

    unfoldForAll() {
      this.cancelFilter();
      this.set("filter", "unfold_all");
      return this.refresh();
    },

    enfoldForAll() {
      this.cancelFilter();
      return this.refresh();
    },

    refreshPostStream() {
      return this.refresh();
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
    refreshPostStream() {
      this._topicController()
        .model.postStream.refreshPostStream()
        .then(() => {
          this._refreshController();
        });
    },

    _refreshController() {
      this._topicController().updateQueryParams();
      this._topicController().appEvents.trigger("post-folding-topic-updated");
    },

    _topicController() {
      return this.register.lookup("controller:topic");
    },
  });

  api.decorateWidget("post-contents:after-cooked", (helper) => {
    if (helper?.getModel()?.post_number !== 1) {
      return;
    }

    if (helper.getModel().topic.folding_enabled_by == null) {
      return;
    }
    function _topicController() {
      return helper.register.lookup("controller:topic");
    }

    return helper.h("div.post-folding-tip", [
      helper.h("hr"),
      helper.h("p", I18n.t("post_folding_tip.tip_text")),
      helper.attach("button", {
        action: "toggleUnfoldAll",
        contents: _topicController().filter
          ? I18n.t("post_folding_tip.enfold_all")
          : I18n.t("post_folding_tip.unfold_all"),
        className: `btn btn-link btn-post-unfold-all`,
      }),
    ]);
  });

  api.includePostAttributes("folded_by", "in_folding_enabled_topic", "in_folding_capable_topic");

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

  if (!curUser) {
    return;
  }

  api.addPostMenuButton("post-toggle-folding", (post) => {
    if (post.in_folding_enabled_topic !== true) {
      return;
    }
    if (post.user_id !== curUser.id && !curUser.can_manipulate_post_foldings) {
      return;
    }
    if (post.deleted_at || post.post_number === 1) {
      return;
    }
    const res = {
      action: "toggleFolding",
      position: "second-last-hidden",
      className: "post-toggle-folding",
    };
    if (post.folded_by) {
      if (!curUser.can_manipulate_post_foldings && post.folded_by !== curUser.id) {
        return Object.assign(res, {
          icon: "expand",
          title: "post_folding.unfolding_unavailable",
          disabled: "true",
        });
      } else {
        return Object.assign(res, {
          icon: "expand",
          title: "post_folding.unfolding_post",
        });
      }
    } else {
      return Object.assign(res, {
        icon: "compress",
        title: "post_folding.folding_post",
      });
    }
  });

  api.addPostMenuButton("topic-toggle-folding", (post) => {
    if (post.post_number !== 1) {
      return;
    }
    if (post.deleted_at) {
      return;
    }
    if (post.user_id !== curUser.id && !curUser.can_manipulate_post_foldings) {
      return;
    }
    if (!post.in_folding_capable_topic && !curUser.can_manipulate_post_foldings) {
      return;
    }

    const res = {
      action: "toggleFoldingEnabled",
      position: "second-last-hidden",
      className: "topic-toggle-folding",
    };
    if (post.in_folding_enabled_topic) {
      return Object.assign(res, {
        title: "post_folding.disable_toggle_folding",
        icon: "toggle-on",
      });
    } else {
      return Object.assign(res, {
        title: "post_folding.enable_toggle_folding",
        icon: "toggle-off",
      });
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
        }
        if (post.folded_by) {
          post.setProperties({
            folded_by: null,
          });
        } else {
          post.setProperties({
            folded_by: curUser.id,
          });
        }
        this.appEvents.trigger("post-stream:refresh", {
          id: post.id,
        });
        this.appEvents.trigger("header:update-topic", post);
      })
      .catch(popupAjaxError);
  });

  api.attachWidgetAction("post", "toggleFoldingEnabled", function () {
    const post = this.model;
    ajax("/post_foldings/toggle_folding_enabled", {
      method: "POST",
      data: { topic: post.topic.id },
    })
      .then((res) => {
        if (!res.succeed) {
          getOwner(this).lookup("service:dialog").alert(res.message);
          return;
        }
        if (post.topic.folding_enabled_by) {
          post.topic.setProperties({
            folding_enabled_by: null,
          });
        } else {
          post.topic.setProperties({
            folding_enabled_by: curUser.id,
          });
        }
        const current = post.get("topic.postStream.posts");
        current.forEach((p) => {
          p.setProperties({
            in_folding_enabled_topic: !p.in_folding_enabled_topic,
          });
          this.appEvents.trigger("post-stream:refresh", { id: p.id });
        });
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
