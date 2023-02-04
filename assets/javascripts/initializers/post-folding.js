import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";

function init(api) {
  const curUser = api.getCurrentUser();
  api.addPostMenuButton("toggle-folding", (post) => {
    if (post.user.id !== curUser.id && !curUser.can_manipulate_post_foldings) {
      return;
    }
    return {
      action: "toggleFolding",
      icon: "compress",
      title: "post_folding.toggle_folding",
      position: "second-last-hidden",
    };
  });
  // Arrow functions won't take this, so use functions
  api.attachWidgetAction("post", "toggleFolding", function () {
    ajax("/post_foldings", {
      method: "POST",
      data: { post: this.model.id },
    })
      .then((res) => {
        if (!res.succeed) {
          getOwner(this).lookup("service:dialog").alert(res.message);
          return;
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
