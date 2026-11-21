import { receipt, help } from "./art/desk";
import { workshop, checklist } from "./art/operations";
import { road, dossier } from "./art/vehicle";
import { serviceHistory } from "./art/service-history";
import { question } from "./art/question";
import { globe } from "./art/globe";
import { keys } from "./art/keys";

const scenes = { question, globe, serviceHistory, dossier, road, receipt, workshop, checklist, help, keys };

export function GarageArt({ kind }: { kind: keyof typeof scenes }) {
  // Preserve the leading spaces that locate each object on the character grid.
  const drawing = scenes[kind].replace(/^\n|\n$/g, "");
  const runs = drawing.split(/(@+|[.:]{3,})/g);

  return (
    <div className="garage-art" aria-hidden="true">
      <pre><span>{runs.map((run, index) => {
        if (run.startsWith("@")) return <b key={index}>{run}</b>;
        if (/^[.:]{3,}$/.test(run)) return <i key={index}>{run}</i>;
        return run;
      })}</span></pre>
    </div>
  );
}
