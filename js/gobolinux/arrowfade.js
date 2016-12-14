
var downArrow = document.getElementById('down_arrow');
function renderDownArrow() {
   var daCanvas = document.getElementById('down_arrow_canvas');
   var da2 = document.getElementById('down_arrow_2');
   daCanvas.width = da2.offsetWidth;
   daCanvas.height = da2.offsetHeight;
   var daCtx = daCanvas.getContext("2d");
   daCtx.fillStyle="#fff";
   daCtx.beginPath();
   daCtx.moveTo(0, 0);
   daCtx.lineTo(daCanvas.height, daCanvas.height);
   daCtx.lineTo(0, daCanvas.height);
   daCtx.closePath();
   daCtx.fill();
   daCtx.beginPath();
   daCtx.moveTo(daCanvas.height, daCanvas.height);
   daCtx.lineTo(daCanvas.height * 2, 0);
   daCtx.lineTo(daCanvas.width, 0);
   daCtx.lineTo(daCanvas.width, daCanvas.height);
   daCtx.closePath();
   daCtx.fill();
}
if (downArrow !== null) {
   renderDownArrow();
}

var base = 0.6;
var limit = window.innerHeight * 0.4;
var contentBg = document.getElementById('first_content_block');
function setContentBackground() {
   var scrollTop = window.pageYOffset;
   if (scrollTop > limit) {
      if (downArrow !== null) {
         downArrow.style.opacity = 1;
      }
      contentBg.style.backgroundColor = "#ffffffff";
   } else {
      var opacity = scrollTop / limit * (1-base) + base;
      if (downArrow !== null) {
         downArrow.style.opacity = opacity;
      }
      contentBg.style.background = "linear-gradient(rgba(255,255,255,"+opacity+") 0%, rgb(255,255,255) 30vh)";
   }
}
setContentBackground();
window.addEventListener('scroll', function() {
   requestAnimationFrame(setContentBackground);
}, false);

