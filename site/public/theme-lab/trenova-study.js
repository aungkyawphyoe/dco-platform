const root = document.documentElement;
const themeButton = document.querySelector('.theme');
const tabs = [...document.querySelectorAll('[role="tab"]')];
const screen = document.querySelector('#app-screen');
const panel = document.querySelector('#screen-panel');
const caption = document.querySelector('#screen-caption');
const captions = {
  dashboard: 'Your garage at a glance',
  fuel: 'Fuel logs, captured straight from AutoX',
  maintenance: 'Know what needs attention',
  garage: 'A record for every vehicle',
};
function updateScreen() {
  const active = tabs.find(tab => tab.getAttribute('aria-selected') === 'true');
  const name = active.dataset.screen;
  const mode = root.classList.contains('light') ? 'light' : 'dark';
  screen.src = `/screenshots/app-${name}-${mode}.webp`;
  screen.alt = `AutoX ${active.querySelector('strong').textContent.toLowerCase()} screen in ${mode} mode`;
  caption.textContent = captions[name];
  panel.setAttribute('aria-labelledby', active.id);
}
function selectTab(selected) {
  tabs.forEach(tab => {
    const active = selected === tab;
    tab.setAttribute('aria-selected', String(active));
    tab.tabIndex = active ? 0 : -1;
  });
  updateScreen();
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', event => {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    let next;
    if (event.key === 'ArrowDown') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowUp') next = (index - 1 + tabs.length) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next === undefined) return;
    event.preventDefault();
    selectTab(tabs[next]);
    tabs[next].focus();
  });
});
themeButton.addEventListener('click', () => {
  const light = root.classList.toggle('light');
  root.classList.toggle('dark', !light);
  const label = light ? 'Use dark theme' : 'Use light theme';
  themeButton.setAttribute('aria-label', label);
  themeButton.title = label;
  themeButton.textContent = light ? '◐' : '☼';
  updateScreen();
});
document.querySelectorAll('.menu-content a').forEach(link => {
  link.addEventListener('click', () => { document.querySelector('.menu').open = false; });
});
const motionButton = document.querySelector('.poster-motion');
motionButton.addEventListener('click', () => {
  const paused = document.querySelector('.hero').classList.toggle('motion-paused');
  motionButton.setAttribute('aria-pressed', String(paused));
  motionButton.textContent = paused ? 'Play animation' : 'Pause animation';
});
