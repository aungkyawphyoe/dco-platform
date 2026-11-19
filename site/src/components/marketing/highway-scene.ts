/** Paint the garage highway on a low-resolution grid, then draw each cell at display size. */
export function createHighwayScene(output: CanvasRenderingContext2D, paint: CanvasRenderingContext2D) {
  const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  let cols = 0, rows = 0, pitch = 5;
  const palettes = {
    dark: ['#060b15', '#0c1930', '#152944', '#243955', '#151716', '#35372e', '#6b622c', '#a29630', '#c8ae39', '#ed7b20', '#ffa31a', '#b54b1a', '#44734b', '#797b78', '#c5bca1', '#e9e5cc'],
    light: ['#f4f2de', '#dae5ed', '#b7c9df', '#849dbf', '#202725', '#464b44', '#84866d', '#c1b847', '#e8cd55', '#e97020', '#ffa31a', '#bc541f', '#418867', '#8a948a', '#b5b7a2', '#eeeacb'],
  };
  const parse = (hex: string) => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  // Quantization is cached per 5-bit RGB value, so each frame remains small.
  const caches = { dark: new Map<number, string>(), light: new Map<number, string>() };
  const rgb = Object.fromEntries(Object.entries(palettes).map(([mode, list]) => [mode, list.map(parse)]));
  function nearest(r: number, g: number, b: number, mode: "dark" | "light", region: number) {
    const key = (region << 15) | ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
    const cached = caches[mode].get(key);
    if (cached) return cached;
    let best = 0, distance = Infinity;
    rgb[mode].forEach((color, i) => {
      if (region === 1 && ![0, 1, 2, 3, 13, 14, 15].includes(i)) return;
      if (region === 2 && ![4, 5, 6, 10, 14, 15].includes(i)) return;
      const d = (r - color[0]) ** 2 * .3 + (g - color[1]) ** 2 * .59 + (b - color[2]) ** 2 * .11;
      if (d < distance) { distance = d; best = i; }
    });
    const result = palettes[mode][best];
    caches[mode].set(key, result);
    return result;
  }
  function noise(x: number, y: number, seed = 0) {
    let value = Math.imul(x + seed * 97, 374761393) + Math.imul(y + 31, 668265263);
    value = Math.imul(value ^ (value >>> 13), 1274126177);
    return ((value ^ (value >>> 16)) >>> 0) / 4294967295;
  }
  function polygon(points: number[][], color: string) {
    paint.fillStyle = color;
    paint.beginPath();
    points.forEach(([x, y], i) => i ? paint.lineTo(x, y) : paint.moveTo(x, y));
    paint.closePath(); paint.fill();
  }
  function rect(x: number, y: number, w: number, h: number, color: string) {
    paint.fillStyle = color; paint.fillRect(x, y, w, h);
  }
  function disc(x: number, y: number, radius: number, color: string) {
    paint.fillStyle = color; paint.beginPath(); paint.arc(x, y, radius, 0, Math.PI * 2); paint.fill();
  }
  function draw(seconds: number, light: boolean) {
    if (!cols || !rows) return;
    const mode = light ? 'light' : 'dark';
    const w = cols, h = rows, horizon = h * .74;
    const sky = paint.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, light ? '#d7e4f3' : '#0c1832');
    sky.addColorStop(1, light ? '#b5c9e4' : '#152647');
    paint.fillStyle = sky; paint.fillRect(0, 0, w, h);
    if (light) {
      const radius = Math.max(7, w * .065);
      disc(w * .84, h * .66, radius + 2, '#e97020');
      disc(w * .84, h * .66, radius, '#ffa31a');
      // Sparse square fragments soften the edge of the setting sun.
      for (let i = 0; i < 70; i++) {
        const angle = noise(i, 4) * Math.PI * 2;
        const r = radius + 1 + noise(i, 9) * 4;
        rect(w * .84 + Math.cos(angle) * r, h * .66 + Math.sin(angle) * r, .7, .7, '#e89c32');
      }
    } else {
      for (let i = 0; i < 180; i++) {
        const x = (noise(i, 3) * w + seconds * .08) % w;
        const y = noise(i, 7) * horizon;
        const bright = Math.sin(seconds * .45 + i) > -.2;
        rect(x, y, noise(i, 13) > .9 ? 1.3 : .65, .7, bright ? '#e9e5cc' : '#797b78');
      }
      const radius = Math.max(6, w * .038), mx = w * .84, my = h * .34;
      paint.save(); paint.beginPath(); paint.arc(mx, my, radius, 0, Math.PI * 2); paint.clip();
      disc(mx, my, radius, '#e9e5cc');
      disc(mx + radius * .48, my - radius * .35, radius, '#10213d');
      paint.restore();
    }
    if (light) {
      for (let i = 0; i < 4; i++) {
        const x = ((i * .37 + seconds * .0015) % 1.4 - .2) * w;
        const y = h * (.19 + (i % 3) * .14);
        rect(x, y, w * .1, 1, '#e8edf0');
        rect(x + 4, y - 1, w * .07, 1, '#e8edf0');
      }
    }
    // Lower, closer viewpoint with a larger skyline: warm facades, shadowed sides, lit windows.
    for (let layer = 0; layer < 2; layer++) {
      const count = layer ? 45 : 60;
      for (let i = 0; i < count; i++) {
        const x = i * w / count - 1;
        if (x > w * .46 && x < w * .57) continue;
        const bw = w / count + 1;
        const bh = h * (.03 + noise(i, layer + 21) * (layer ? .20 : .14));
        const y = horizon - bh + layer * 2;
        const warm = noise(i, layer + 8) > .42;
        rect(x, y, bw, bh + 4, layer ? (warm ? '#ae6a2b' : '#333c3a') : (light ? '#8a948a' : '#243955'));
        if (layer) {
          rect(x + bw * .65, y, bw * .35, bh + 3, '#262e2b');
          rect(x, y, bw, 1, '#e97020');
          if (i % 4 === 0) rect(x + bw * .45, y - 3, .65, 3, light ? '#657568' : '#797b78');
          for (let wy = y + 2; wy < horizon; wy += 3) {
            for (let wx = x + 1; wx < x + bw - 1; wx += 2) {
              const on = noise(Math.floor(wx), Math.floor(wy), i) > .48;
              if (on) rect(wx, wy, .8, 1, light ? '#d3bd67' : (Math.sin(seconds * .55 + i + wy) > -.7 ? '#f1ba4b' : '#97672e'));
            }
          }
        }
      }
    }
    const vx = w * .51;
    polygon([[0, horizon], [w, horizon], [w, h], [0, h]], light ? '#dfcc53' : '#a49b2b');
    // Vergetop texture follows the same slow forward travel as the road.
    for (let i = 0; i < 250; i++) {
      const phase = (noise(i, 23) + seconds * .045) % 1;
      const y = horizon + phase ** 1.5 * (h - horizon);
      const x = noise(i, 31) * w;
      rect(x, y, .5 + phase * 1.5, .5 + phase, i % 4 ? '#8b923a' : '#398763');
    }
    polygon([[vx - 3, horizon - 1], [vx + 3, horizon - 1], [w * .95, h], [w * .05, h]], '#1d211f');
    for (let i = 0; i < 270; i++) {
      const p = (noise(i, 44) + seconds * .08) % 1;
      const y = horizon + p ** 1.7 * (h - horizon);
      const spread = p ** 1.7 * w * .43;
      const x = vx + (noise(i, 45) * 2 - 1) * spread;
      rect(x, y, .5, .6, '#514b30');
    }
    for (let i = 0; i < 5; i++) {
      const p = ((seconds * .4 + i / 5) % 1);
      const near = p * p;
      const y = horizon + near * (h - horizon);
      rect(vx - .25 - near * .6, y, .5 + near * 1.4, 1 + near * 5.5, '#ffbd3d');
    }
    // Closer hatchback and taller city retain the long-road composition.
    const cw = Math.max(15, w * .115), ch = cw * .72;
    const cx = w * .549 + Math.sin(seconds * 1.5) * .35;
    const cy = horizon + h * .055 + Math.sin(seconds * 3) * .22;
    rect(cx - cw * .55, cy + ch * .77, cw * 1.1, 1.5, '#101714');
    rect(cx - cw * .5, cy + ch * .44, cw * .14, ch * .42, '#101714');
    rect(cx + cw * .36, cy + ch * .44, cw * .14, ch * .42, '#101714');
    polygon([[cx - cw * .48, cy + ch * .72], [cx - cw * .48, cy + ch * .34], [cx - cw * .32, cy], [cx + cw * .32, cy], [cx + cw * .48, cy + ch * .34], [cx + cw * .48, cy + ch * .72]], light ? '#e9e5cc' : '#797b85');
    polygon([[cx - cw * .31, cy + ch * .1], [cx + cw * .31, cy + ch * .1], [cx + cw * .4, cy + ch * .36], [cx - cw * .4, cy + ch * .36]], light ? '#546479' : '#24314d');
    rect(cx - cw * .45, cy + ch * .51, cw * .9, ch * .15, light ? '#c5bca1' : '#454e66');
    rect(cx - cw * .45, cy + ch * .5, cw * .2, 1, '#ed7b20');
    rect(cx + cw * .25, cy + ch * .5, cw * .2, 1, '#ed7b20');
    rect(cx - cw * .15, cy + ch * .62, cw * .3, .8, '#e9e5cc');
    // Quantize at the cell level, then leave a true one-pixel line between cells.
    const data = paint.getImageData(0, 0, cols, rows).data;
    output.fillStyle = light ? '#b5bec6' : '#070a0d';
    output.fillRect(0, 0, output.canvas.width, output.canvas.height);
    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const i = (y * cols + x) * 4;
        const onRoad = y >= horizon && Math.abs(x - vx) < (y - horizon) / (h - horizon) * w * .44;
        const onCar = Math.abs(x - cx) < cw * .6 && y >= cy - 1 && y < cy + ch + 2;
        const skyPixel = y < horizon && data[i + 2] > data[i] + 4;
        const region = skyPixel ? 1 : onRoad && !onCar ? 2 : 0;
        const d = (bayer[(y % 4) * 4 + x % 4] / 16 - .5) * (region === 2 ? 20 : y < horizon ? 23 : 36);
        const channel = (n: number) => Math.max(0, Math.min(255, Math.round(n + d)));
        output.fillStyle = nearest(channel(data[i]), channel(data[i + 1]), channel(data[i + 2]), mode, region);
        output.fillRect(x * pitch, y * pitch, pitch - 1, pitch - 1);
      }
    }
  }
  function resize(width: number, height: number) {
    pitch = width < 600 ? 4 : 5;
    cols = Math.ceil(width / pitch);
    rows = Math.ceil(height / pitch);
    output.canvas.width = width;
    output.canvas.height = height;
    paint.canvas.width = cols;
    paint.canvas.height = rows;
  }
  return { resize, draw };
}
