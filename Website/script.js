(function () {
  var sections = Array.prototype.slice.call(document.querySelectorAll('main [id]'));
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav nav a[href^="#"]'));
  var cards = Array.prototype.slice.call(document.querySelectorAll('.card'));
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function setActive(id) {
    links.forEach(function (link) {
      link.classList.toggle('active', link.getAttribute('href') === '#' + id);
    });
  }

  if ('IntersectionObserver' in window) {
    var sectionObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) setActive(entry.target.id);
      });
    }, { rootMargin: '-18% 0px -68% 0px' });

    sections.forEach(function (section) { sectionObserver.observe(section); });

    if (!reducedMotion) {
      var revealObserver = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('visible');
          revealObserver.unobserve(entry.target);
        });
      }, { rootMargin: '0px 0px -8% 0px' });

      cards.forEach(function (card) {
        card.classList.add('reveal');
        revealObserver.observe(card);
      });
    }
  }
}());
