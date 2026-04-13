(function () {
  var cards = document.querySelectorAll('.card, .hero');
  cards.forEach(function (card) {
    card.addEventListener('mousemove', function (event) {
      var rect = card.getBoundingClientRect();
      var x = (event.clientX - rect.left) / rect.width - 0.5;
      var y = (event.clientY - rect.top) / rect.height - 0.5;
      card.style.transform = 'perspective(900px) rotateX(' + (-y * 3.5) + 'deg) rotateY(' + (x * 4.5) + 'deg)';
    });

    card.addEventListener('mouseleave', function () {
      card.style.transform = 'perspective(900px) rotateX(0deg) rotateY(0deg)';
    });
  });

  var blobs = document.querySelectorAll('.blob');
  window.addEventListener('mousemove', function (event) {
    var x = event.clientX / window.innerWidth;
    var y = event.clientY / window.innerHeight;
    blobs.forEach(function (blob, index) {
      var dx = (x - 0.5) * (10 + index * 8);
      var dy = (y - 0.5) * (10 + index * 8);
      blob.style.transform = 'translate(' + dx + 'px, ' + dy + 'px)';
    });
  }, { passive: true });
}());
