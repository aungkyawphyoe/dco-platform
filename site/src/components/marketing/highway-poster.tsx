"use client";

import { useEffect, useRef, useState } from "react";
import type { Dictionary } from "@/i18n/types";

export function HighwayPoster({ labels }: { labels: Dictionary["home"]["motion"] }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const update = useRef<() => void>(() => {});
  const paused = useRef(false);
  const [playing, setPlaying] = useState(true);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    let disposed = false;
    let cleanup: (() => void) | undefined;

    async function mount(canvas: HTMLCanvasElement) {
      const { createHighwayScene } = await import("./highway-scene");
      if (disposed) return;
      const output = canvas.getContext("2d", { alpha: false });
      const source = document.createElement("canvas").getContext("2d", { willReadFrequently: true });
      if (!output || !source) return;
      const scene = createHighwayScene(output, source);
      let frame = 0;
      let last = 0;
      let elapsed = 1.4;
      let visible = false;
      const draw = () => scene.draw(elapsed, document.documentElement.classList.contains("light"));
      function tick(now: number) {
        if (now - last >= 50) {
          elapsed += last ? Math.min(now - last, 100) / 1000 : 0;
          last = now;
          draw();
        }
        frame = requestAnimationFrame(tick);
      }
      function refresh() {
        cancelAnimationFrame(frame);
        last = 0;
        if (document.hidden || !visible || motion.matches) return;
        draw();
        if (!paused.current) frame = requestAnimationFrame(tick);
      }
      function resize() {
        scene.resize(Math.max(1, canvas.clientWidth), Math.max(1, canvas.clientHeight));
        refresh();
      }
      const size = new ResizeObserver(resize);
      const theme = new MutationObserver(refresh);
      const intersection = new IntersectionObserver(([entry]) => {
        visible = entry.isIntersecting;
        refresh();
        if (visible) setReady(true);
      });
      cleanup = () => {
        cancelAnimationFrame(frame);
        size.disconnect();
        theme.disconnect();
        intersection.disconnect();
        motion.removeEventListener("change", refresh);
        document.removeEventListener("visibilitychange", refresh);
        update.current = () => {};
      };
      resize();
      size.observe(canvas);
      theme.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
      intersection.observe(canvas);
      motion.addEventListener("change", refresh);
      document.addEventListener("visibilitychange", refresh);
      update.current = refresh;
    }
    // The server-rendered still remains visible if canvas or the renderer is unavailable.
    mount(canvas).catch(() => { cleanup?.(); setReady(false); });
    return () => { disposed = true; cleanup?.(); };
  }, []);

  return (
    <>
      <div className="highway-scene" aria-hidden="true">
        <canvas ref={canvasRef} className={ready ? "ready" : undefined} />
      </div>
      {ready && <button type="button" className="motion-control" onClick={() => {
        paused.current = !paused.current;
        setPlaying(!paused.current);
        update.current();
      }}>{playing ? labels.pause : labels.play}</button>}
    </>
  );
}
