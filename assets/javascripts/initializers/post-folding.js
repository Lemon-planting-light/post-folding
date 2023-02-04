import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";

function init(api) {

  api.includePostAttributes(
    "folded_by"
  );

  api.addPostClassesCallback((attrs) => {
    // Not folded
    if (attrs.folded_by === null) {
      return [];
    } else if (attrs.folded_by === curUser.id) {
      return ["folded", "folded-by-me"];
    } else {
      return ["folded", "folded-by-others"];
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
          disabled: "true"
        };
      } else {
        return {
          action: "toggleFolding",
          icon: "expand",
          title: "post_folding.toggle_folding",
          position: "second-last-hidden",
        };
      }
    } else {
      return {
        action: "toggleFolding",
        icon: "compress",
        title: "post_folding.toggle_folding",
        position: "second-last-hidden",
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
  name: "post-folding",

  initialize(container) {
    if (!container.lookup("site-settings:main").post_folding_enabled) {
      return;
    }
    withPluginApi("1.6.0", init);
  },
};
