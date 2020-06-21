$(document).ready(function () {
  var galleries = $(".ad-gallery").adGallery({
    loader_image: "javascripts/jquery.ad-gallery/images/loader.gif",
    width: 650,
    height: 650,
    description_wrapper: $("#gallery-descriptions"),
    display_back_and_forward: false, // Are you allowed to scroll the thumb list?
    slideshow: {
      enable: false,
    },
    callbacks: {
      // Executes right after the internal init, can be used to choose which images
      // you want to preload
      init: function () {
        // preloadAll uses recursion to preload each image right after one another
        this.preloadAll();
      },
      beforeImageVisible: function (new_image, old_image) {
        if (this.current_description) {
          this.current_description.remove();
        }
      },
    },
  });

  $("pre.documentation").each(function () {
    this.innerHTML = this.innerHTML.replace(
      /(   \-\w+,\s*)(\-\-\w*)/gi,
      "$1<span class='argument'>$2</span>"
    );
    this.innerHTML = this.innerHTML.replace(
      /(   )(\-\-?\w+)/gi,
      "$1<span class='argument'>$2</span>"
    );
  });

  $("span.command").click(function () {
    var command = $(this)
      .html()
      .replace(/\..*?$/, "");
    window.location = "commands.html#" + command;
  });

  $("table.colored-rows tr:odd").addClass("odd-rows");
  $("table.colored-rows tr:even").addClass("even-rows");
});
