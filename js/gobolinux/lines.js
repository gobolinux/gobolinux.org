
var canvas = document.getElementById('parallax_lines');
canvas.width = canvas.clientWidth;
canvas.height = canvas.clientHeight;
var width = canvas.offsetWidth;
var height = canvas.offsetHeight;

var layers = [];
var nt = 10;

function randomBetween(from, to) {
   return Math.floor((Math.random() * to) + from);
}

for (var i = 0; i < nt; i++) {
   var layer = {};
   layer.rx = randomBetween(0, width);
   layer.ry = randomBetween(0, height);
   
   layer.ax = randomBetween(0, width);
   layer.ay = randomBetween(0, height);
   
   layer.bx = randomBetween(-width / 2, width * 2);
   layer.by = randomBetween(-height / 2, height * 2);
   
   var min, max;
   min = Math.min(layer.ax, layer.bx);
   max = Math.max(layer.ax, layer.bx);
   layer.ax = min; layer.bx = max;
   min = Math.min(layer.ay, layer.by);
   max = Math.max(layer.ay, layer.by);
   layer.ay = min; layer.by = max;

   layers[i] = layer;
}

var ctx = canvas.getContext("2d");
ctx.lineWidth = height / 720;
function scanlines() {
   ctx.strokeStyle="#000000";
   ctx.beginPath();
   for (var i = 1; i <= 256; i++) {
      ctx.moveTo(0, height / 256 * i)
      ctx.lineTo(width, height / 256 * i)
   }
   ctx.stroke();
}

function drawObjects(offset) {
   var ln = 75;
   for (var a = 0; a < nt; a++) {
      var l = layers[a];
      var fac = a / nt;
      for (var i = 0; i < ln; i++) {
         var pc = i / ln;
         var color = "rgb(" + Math.floor(((i - 25) / ln * fac) * 255) +","+ Math.floor(((ln - i) / ln * fac) * 255) +","+ Math.floor(((i + 50) / ln * fac) * 255) +")";
         ctx.strokeStyle = color;
         ctx.beginPath();
         var dx, dy;
         switch (a % 4) {
         case 0:
            ctx.moveTo(l.rx - offset, l.ry);
            dx = l.ax + (l.bx - l.ax) * pc - offset;
            dy = l.ay + (l.by - l.ay) * pc - offset;
            break;
         case 1:
            ctx.moveTo(l.rx, l.ry + offset);
            dx = l.bx - (l.bx - l.ax) * pc - offset;
            dy = l.by - (l.by - l.ay) * pc + offset;
            break;
         case 2:
            ctx.moveTo(l.rx + offset, l.ry);
            dx = l.ax + (l.bx - l.ax) * pc + offset;
            dy = l.ay + (l.by - l.ay) * pc - offset;
            break;
         case 3:
            ctx.moveTo(l.rx, l.ry - offset);
            dx = l.bx - (l.bx - l.ax) * pc + offset;
            dy = l.by - (l.by - l.ay) * pc + offset;
            break;
         }
         ctx.lineTo(dx, dy);
         ctx.stroke();
      }
   }
}

drawObjects(0);
scanlines();

