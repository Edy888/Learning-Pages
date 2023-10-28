document.addEventListener("DOMContentLoaded", function() {
  let sidebar = document.querySelector('.sidebar');
  let myLearningLink = document.querySelector('a[href="Моё_обучение"]');

  if (sidebar && myLearningLink) {
    myLearningLink.addEventListener('click', function(event) {
      event.preventDefault(); // Предотвращаем переход по ссылке
      sidebar.classList.add('sidebar-visible'); // Добавляем класс для показа боковой панели
    });

    document.body.addEventListener('click', function(event) {
      if (event.target !== myLearningLink && !sidebar.contains(event.target)) {
        sidebar.classList.remove('sidebar-visible'); // Удаляем класс и скрываем панель
      }
    });
  }
});
