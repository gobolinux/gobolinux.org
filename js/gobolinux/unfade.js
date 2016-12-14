
function unfade(element, limit) {
   if (limit === undefined) {
      limit = 1;
   }
   var op = 0.03; // initial opacity
   element.style.display = 'block';
   var timer;
   timer = window.setInterval(function () {
      if (op >= limit){
         window.clearInterval(timer);
      }
      element.style.opacity = op;
      element.style.filter = 'alpha(opacity=' + op * 100 + ")";
      op += op * 0.1;
   }, 30);
}

unfade(document.getElementById('intro_text'));
unfade(document.getElementById('logo'));

