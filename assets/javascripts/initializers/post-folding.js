import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";
import I18n from "I18n";
import { avatarFor } from "discourse/widgets/post";

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

  api.decorateWidget("post-menu:after", (helper) => {
    if (helper?.getModel()?.folded_by) {
      const user = helper?.getModel()?.folded_by;
      return helper.h("div.clearfix.small-user-list.post-folded-by", [
        avatarFor("small", {
          username: user.username,
          template: user.avatar_template,
          url: `/u/${user.username}`,
        }),
        helper.h("span", I18n.t("post_folding_by.description")),
      ]);
    } else return;
  });

  api.includePostAttributes("folded_by", "in_folding_enabled_topic", "in_folding_capable_topic");

  api.addPostClassesCallback((attrs) => {
    // Not folded
    if (attrs.folded_by === null) {
      return [];
    } else {
      if (attrs.folded_by?.id === curUser?.id) {
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
    if ((post.user_id !== curUser.id || !post.canEdit) && !curUser.can_manipulate_post_foldings) {
      return;
    }
    if (post.locked && !curUser.staff) {
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
    if (!curUser.can_manipulate_post_foldings) {
      res.action = "toggleFoldingByUser";
    }
    if (post.folded_by) {
      res.icon = "expand";
      res.title = "post_folding.unfolding_post";
      if (!curUser.can_manipulate_post_foldings && post.folded_by?.id !== curUser.id) {
        res.action = "toggleFoldingDisabled";
        res.title = "post_folding.unfolding_unavailable";
      }
    } else {
      res.icon = "compress";
      res.title = "post_folding.folding_post";
    }
    return res;
  });

  api.addPostMenuButton("topic-toggle-folding", (post) => {
    if (post.post_number !== 1) {
      return;
    }
    if (post.deleted_at) {
      return;
    }
    if ((post.user_id !== curUser.id || !post.canEdit) && !curUser.can_manipulate_post_foldings) {
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

  function toggleFolding(helper) {
    const post = helper.model;
    ajax("/post_foldings", {
      method: "POST",
      data: { post: post.id },
    })
      .then((res) => {
        if (!res.succeed) {
          getOwner(helper).lookup("service:dialog").alert(res.message);
          return;
        }
        if (post.folded_by) {
          post.setProperties({
            folded_by: null,
          });
        } else {
          post.setProperties({
            folded_by: curUser,
          });
        }
        helper.appEvents.trigger("post-stream:refresh", {
          id: post.id,
        });
      })
      .catch(popupAjaxError);
  }

  function toggleFoldingEnabled(helper) {
    const post = helper.model;
    ajax("/post_foldings/toggle_folding_enabled", {
      method: "POST",
      data: { topic: post.topic.id },
    })
      .then((res) => {
        if (!res.succeed) {
          getOwner(helper).lookup("service:dialog").alert(res.message);
          return;
        }
        if (post.topic.folding_enabled_by) {
          post.topic.setProperties({
            folding_enabled_by: null,
          });
        } else {
          post.topic.setProperties({
            folding_enabled_by: curUser,
          });
        }
        const current = post.get("topic.postStream.posts");
        current.forEach((p) => {
          p.setProperties({
            in_folding_enabled_topic: !p.in_folding_enabled_topic,
          });
          helper.appEvents.trigger("post-stream:refresh", { id: p.id });
        });
      })
      .catch(popupAjaxError);
  }

  // Arrow functions won't take this, so use functions
  api.attachWidgetAction("post", "toggleFolding", function () {
    const helper = this;
    toggleFolding(helper);
  });
  api.attachWidgetAction("post", "toggleFoldingByUser", function () {
    const helper = this;
    const post = helper.model;
    // Only show modal when post is folded
    if (post.folded_by || curUser.siteSettings?.post_folding_disable_confirm) {
      toggleFolding(helper);
    } else {
      getOwner(helper)
        .lookup("service:dialog")
        .confirm({
          message: I18n.t("post_folding_confirm.folding_post"),
          didConfirm: () => {
            toggleFolding(helper);
          },
        });
    }
  });
  api.attachWidgetAction("post", "toggleFoldingDisabled", function () {
    getOwner(this)
      .lookup("service:dialog")
      .alert({
        message: I18n.t("post_folding.unfolding_unavailable"),
      });
  });

  api.attachWidgetAction("post", "toggleFoldingEnabled", function () {
    const helper = this;
    const topic = helper.model.topic;
    if (curUser.siteSettings?.post_folding_disable_confirm) {
      toggleFoldingEnabled(helper);
    } else {
      // Always show whether can_manipulate_post_foldings
      getOwner(helper)
        .lookup("service:dialog")
        .confirm({
          message: topic.folding_enabled_by
            ? I18n.t("post_folding_confirm.disable_toggle_folding")
            : I18n.t("post_folding_confirm.enable_toggle_folding"),
          didConfirm: () => {
            toggleFoldingEnabled(helper);
          },
        });
    }
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
