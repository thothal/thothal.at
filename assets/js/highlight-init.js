(function () {
   function detectPandocLanguage(codeElement) {
      var pre = codeElement && codeElement.parentElement;
      if (!pre || pre.tagName !== "PRE") {
         return null;
      }

      var classes = pre.className ? pre.className.split(/\s+/) : [];
      for (var i = 0; i < classes.length; i += 1) {
         var cls = classes[i].toLowerCase();
         if (cls === "r" || cls === "sql" || cls === "python" || cls === "py") {
            return cls === "py" ? "python" : cls;
         }
      }

      return null;
   }

   function highlightCodeBlocks() {
      if (typeof hljs === "undefined") {
         return;
      }

      var doHighlight = null;
      if (typeof hljs.highlightElement === "function") {
         doHighlight = function (block) {
            hljs.highlightElement(block);
         };
      } else if (typeof hljs.highlightBlock === "function") {
         doHighlight = function (block) {
            hljs.highlightBlock(block);
         };
      } else {
         return;
      }

      var blocks = document.querySelectorAll("pre code");
      for (var i = 0; i < blocks.length; i += 1) {
         var block = blocks[i];
         var lang = detectPandocLanguage(block);

         if (lang && !block.classList.contains("language-" + lang)) {
            block.classList.add("language-" + lang);
         }

         if (lang || /\blanguage-/.test(block.className)) {
            doHighlight(block);
         }
      }
   }

   if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", highlightCodeBlocks);
   } else {
      highlightCodeBlocks();
   }
})();
