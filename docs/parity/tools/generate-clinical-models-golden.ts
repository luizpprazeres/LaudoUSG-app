// Gera LaudoUSGTests/clinical-models-v1-golden.json executando o código real de
// @laudousg/shared (somente leitura no monorepo). Uso, a partir deste repo:
//   (cd "$MONOREPO/packages/shared" && tsx "$OLDPWD/docs/parity/tools/generate-clinical-models-golden.ts") \
//     > LaudoUSGTests/clinical-models-v1-golden.json
// MONOREPO padrão: ~/laudousgmobile-def.
import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { homedir } from "node:os";

const MONOREPO = process.env.MONOREPO ?? `${homedir()}/laudousgmobile-def`;

async function main() {
const { validateClinicalModelInput } = await import(`${MONOREPO}/packages/shared/src/clinicalModels/contracts`);
const { renderClinicalModelReport } = await import(`${MONOREPO}/packages/shared/src/clinicalModels/renderer`);
const { createInitialClinicalModelInput } = await import(`${MONOREPO}/packages/shared/src/clinicalModels/defaults`);

const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v));
const html = readFileSync(`${MONOREPO}/docs/parity/modelos-clinicos-v1-revisao.html`, "utf8");
const review = JSON.parse(html.match(/<script type="application\/json" id="review-data">([\s\S]*?)<\/script>/)![1]);
const reviewCases = review.models.flatMap((m: any) => m.cases.map((c: any) => ({ name: `${m.code}:${c.kind}`, input: c.input })));

const venousNeutral = { examined: false, deepSystem: "not_assessed", superficialSystem: "not_assessed", competenceTested: false, reflux: "not_assessed", internalJugular: "not_assessed", catheter: { present: false }, thrombosisPhase: "not_applicable", phaseConfirmed: false };
const arterialNeutral = { examined: false, status: "normal", psvCms: {}, percentageDataSufficient: false, percentageConfirmed: false, thoracicOutlet: { evaluated: false } };
const hip = (o: any) => ({ adequateStandardPlane: true, alphaDeg: 63, betaDeg: 47, bonyRoof: "normal", cartilaginousRoof: "normal", femoralHead: "centered", labrumPosition: "normal", grafClassification: "I", classificationConfirmed: true, ...o });
const thoraxNormal = { pleuralLine: "regular", sliding: "present", linesB: { count: 0, distribution: "none" }, effusion: { present: false }, consolidation: "not_seen", atelectasis: "not_seen", pneumothorax: "not_seen" };

const byName = (n: string) => clone(reviewCases.find((c: any) => c.name === n)!.input);
const extra: { name: string; input: any }[] = [];

{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.hepaticVeins = { evaluated: true, caliberCm: 0.8, velocityCms: 30, flow: "hepatofugal" };
  a.superiorMesentericVein = { evaluated: true, caliberCm: 0.9, velocityCms: 18.5, flow: "hepatopetal" };
  a.portalVein.flow = "ausente";
  a.portalPathology = { status: "confirmed", kind: "portal_thrombosis", evidence: "Material ecogênico intraluminal e ausência de fluxo ao Doppler", physicianConfirmed: true };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:thrombosis-confirmed", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalVein.flow = "outro"; a.portalPathology = { status: "suspected", kind: "other", evidence: "Fluxo bidirecional no tronco portal", physicianConfirmed: true };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:other-suspected", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:altered"); a.portalPathology = { status: "absent", physicianConfirmed: false };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-hepatofugal-absent", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal"); a.portalVein = { caliberCm: 1.1 };
  a.splenicVein = { evaluated: true, caliberCm: 1 };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-incomplete-vessels", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:altered"); a.portalPathology = { status: "suspected", kind: "portal_hypertension", physicianConfirmed: false };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-portal-unconfirmed", input: a }); }

// Regras portais de 2399a23: fluxo anormal com situação ausente e status incoerente.
// Fisiologia: veias hepáticas drenam para a cava (hepatofugal); demais vasos hepatopetais.
const evaluatedVessel = (flow: string) => ({ evaluated: true, caliberCm: 0.6, velocityCms: 18, flow });
for (const [key, flow] of [
  ["portalVein", "ausente"], ["portalVein", "outro"], ["portalVein", "hepatofugal"],
  ["hepaticVeins", "ausente"], ["hepaticVeins", "outro"],
  ["splenicVein", "hepatofugal"], ["splenicVein", "ausente"],
  ["superiorMesentericVein", "hepatofugal"], ["commonHepaticArtery", "hepatofugal"],
] as const) {
  const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  if (key === "portalVein") a.portalVein.flow = flow; else a[key] = evaluatedVessel(flow);
  extra.push({ name: `ABDOMEN_TOTAL_DOPPLER:block-abnormal-${key}-${flow}`, input: a });
  const resolved = clone(a);
  resolved.portalPathology = { status: "suspected", kind: "other", evidence: "Alteração de fluxo descrita pelo médico", physicianConfirmed: true };
  extra.push({ name: `ABDOMEN_TOTAL_DOPPLER:resolved-${key}-${flow}`, input: resolved });
}
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.hepaticVeins = evaluatedVessel("hepatofugal");
  a.splenicVein = evaluatedVessel("hepatopetal");
  a.superiorMesentericVein = evaluatedVessel("hepatopetal");
  a.commonHepaticArtery = evaluatedVessel("hepatopetal");
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:normal-all-vessels-physiological", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.hepaticVeins = evaluatedVessel("hepatopetal");
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:hepatic-veins-hepatopetal-absent", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalPathology = { status: "absent", kind: "portal_thrombosis", physicianConfirmed: false };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-mismatch-kind", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalPathology = { status: "absent", physicianConfirmed: true };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-mismatch-confirmed", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalPathology = { status: "absent", evidence: "Critério antigo", physicianConfirmed: false };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:block-mismatch-evidence", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalVein.flow = "outro";
  a.portalPathology = { status: "suspected", kind: "other", evidence: "Fluxo portal monofásico, sem sinais de trombose.", physicianConfirmed: true };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:suspected-other-evidence-period", input: a }); }
{ const a = byName("ABDOMEN_TOTAL_DOPPLER:normal");
  a.portalVein.flow = "ausente";
  a.portalPathology = { status: "confirmed", kind: "other", evidence: "Ausência de fluxo detectável no tronco portal;  ", physicianConfirmed: true };
  extra.push({ name: "ABDOMEN_TOTAL_DOPPLER:confirmed-other-evidence-punctuation", input: a }); }

{ const v = byName("DOPPLER_VENOSO_MMSS:normal");
  v.indication = "thrombosis_research";
  v.left = { ...v.left, internalJugular: "patent", competenceTested: true, reflux: "present", superficialSystem: "not_assessed" };
  extra.push({ name: "DOPPLER_VENOSO_MMSS:jugular-reflux", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:altered"); v.laterality = "left"; v.right.thrombosisPhase = "chronic"; v.right.examined = true;
  v.left = { ...venousNeutral, examined: true, superficialSystem: "thrombosis", thrombosisPhase: "indeterminate" };
  v.laterality = "bilateral";
  extra.push({ name: "DOPPLER_VENOSO_MMSS:bilateral-mixed", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:normal"); v.laterality = "right"; v.right = { ...venousNeutral, examined: true, deepSystem: "patent" }; v.left = clone(venousNeutral);
  extra.push({ name: "DOPPLER_VENOSO_MMSS:right-only", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:normal"); v.left.examined = false;
  extra.push({ name: "DOPPLER_VENOSO_MMSS:block-bilateral-left-not-examined", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:altered"); v.right.phaseConfirmed = false;
  extra.push({ name: "DOPPLER_VENOSO_MMSS:block-phase-unconfirmed", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:normal"); v.right.reflux = "absent";
  extra.push({ name: "DOPPLER_VENOSO_MMSS:block-reflux-not-tested", input: v }); }
{ const v = byName("DOPPLER_VENOSO_MMSS:altered"); v.right.catheter = { present: true, relation: "adjacent" };
  extra.push({ name: "DOPPLER_VENOSO_MMSS:block-catheter-segment", input: v }); }

{ const a = byName("DOPPLER_ARTERIAL_MMSS:normal");
  a.right = { ...a.right, status: "occlusion", affectedVessel: "artéria radial direita", psvCms: { "artéria braquial direita": 62.5 }, distalPattern: "reenchimento distal por colaterais" };
  a.left = { ...a.left, status: "other", affectedVessel: "artéria ulnar esquerda", psvCms: { "artéria ulnar esquerda": 140 }, thoracicOutlet: { evaluated: true, maneuvers: "manobra de Adson", positions: "posição neutra", result: "indeterminate", physicianConfirmed: true } };
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:occlusion-other", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); a.left.stenosisPercent = undefined; delete a.left.stenosisPercent; a.left.percentageDataSufficient = false; a.left.percentageConfirmed = false; a.left.thoracicOutlet = { evaluated: true, maneuvers: "abdução", positions: "neutra", result: "negative", physicianConfirmed: true };
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:stenosis-qualitative", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); a.left.distalPattern = "fluxo amortecido, com reenchimento distal.";
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:distal-pattern-period", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); a.left.percentageConfirmed = false;
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:block-percent-unconfirmed", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); delete a.left.distalPattern;
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:block-distal-pattern", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); a.left.psvCms = {};
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:block-missing-psv", input: a }); }
{ const a = byName("DOPPLER_ARTERIAL_MMSS:altered"); a.left.thoracicOutlet.physicianConfirmed = false;
  extra.push({ name: "DOPPLER_ARTERIAL_MMSS:block-outlet-unconfirmed", input: a }); }

{ const t = byName("TORAX:normal");
  t.left = { ...thoraxNormal, effusion: { present: true, separationMm: 22.5, context: { adult: true, mechanicallyVentilated: true, supineTorso15Deg: true, endExpirationPosteriorAxillary: true, physicianConfirmed: true } }, linesB: { count: 3, distribution: "multifocal" }, atelectasis: "confirmed" };
  t.right = { ...thoraxNormal, pneumothorax: "suspected", sliding: "absent" };
  t.limitation = "Janela acústica limitada por enfisema subcutâneo"; t.correlationSuggested = true;
  extra.push({ name: "TORAX:balik-eligible", input: t }); }
{ const t = byName("TORAX:normal"); t.right.pleuralLine = "not_assessed"; t.limitation = "Janela acústica limitada pelo curativo.";
  extra.push({ name: "TORAX:limitation-period", input: t }); }
{ const t = byName("TORAX:normal"); t.right.pleuralLine = "not_assessed";
  extra.push({ name: "TORAX:incomplete-assessment", input: t }); }
{ const t = byName("TORAX:normal"); t.correlationSuggested = true;
  extra.push({ name: "TORAX:block-correlation-without-reason", input: t }); }
{ const t = byName("TORAX:normal"); t.left.linesB = { count: 0, distribution: "focal" };
  extra.push({ name: "TORAX:block-lines-b-distribution", input: t }); }

const hipCase = (name: string, ageDays: number | undefined, right: any, left: any, more: any = {}) =>
  extra.push({ name, input: { schemaVersion: 1, categoryCode: "QUADRIL_INFANTIL", physicianReviewed: false, ...(ageDays == null ? {} : { ageDays }), right: hip(right), left: hip(left), recommendationConfirmed: false, ...more } });
hipCase("QUADRIL_INFANTIL:IIA-IIC", 40, { alphaDeg: 52, betaDeg: 60, bonyRoof: "rounded", grafClassification: "IIA" }, { alphaDeg: 45, betaDeg: 70, bonyRoof: "rounded", grafClassification: "IIC" });
hipCase("QUADRIL_INFANTIL:D-III", 30, { alphaDeg: 45, betaDeg: 80, bonyRoof: "deficient", femoralHead: "decentered", grafClassification: "D" }, { alphaDeg: 40, betaDeg: 90, bonyRoof: "deficient", cartilaginousRoof: "displaced", femoralHead: "dislocated", labrumPosition: "everted", grafClassification: "III" });
hipCase("QUADRIL_INFANTIL:IV", 20, {}, { alphaDeg: 38, betaDeg: 95, bonyRoof: "deficient", cartilaginousRoof: "displaced", femoralHead: "dislocated", labrumPosition: "interposed", grafClassification: "IV" }, { recommendation: "Sugere-se avaliação ortopédica", recommendationConfirmed: true });
hipCase("QUADRIL_INFANTIL:block-mismatch", 60, {}, { alphaDeg: 55, betaDeg: 60, grafClassification: "I" });
hipCase("QUADRIL_INFANTIL:block-unconfirmed", 60, { classificationConfirmed: false }, {});
hipCase("QUADRIL_INFANTIL:block-no-age", undefined, {}, {});
hipCase("QUADRIL_INFANTIL:block-inadequate-plane", 60, { adequateStandardPlane: false }, {});
hipCase("QUADRIL_INFANTIL:block-morphology-insufficient", 60, {}, { alphaDeg: 40, betaDeg: 90, labrumPosition: "normal", grafClassification: undefined, classificationConfirmed: false });
hipCase("QUADRIL_INFANTIL:block-recommendation-unconfirmed", 60, {}, {}, { recommendation: "Controle em 6 semanas" });

const cases = [...reviewCases, ...extra].map(({ name, input }: { name: string; input: any }) => {
  const v = validateClinicalModelInput(input, { requirePhysicianReview: false });
  return {
    name,
    input,
    success: v.success,
    issueCodes: v.issues.map((i) => i.code).sort(),
    warningCodes: v.issues.filter((i) => i.severity === "warning").map((i) => i.code).sort(),
    report: v.success ? renderClinicalModelReport(input) : null,
  };
});

const head = execSync(`git -C ${MONOREPO} rev-parse --short HEAD`).toString().trim();
// Fixture gerada de árvore com alterações não commitadas fica marcada como -dirty.
const dirty = execSync(`git -C ${MONOREPO} status --porcelain -- packages/shared/src/clinicalModels`).toString().trim() !== "";
const sharedCommit = dirty ? `${head}-dirty` : head;
const defaults = Object.fromEntries(["ABDOMEN_TOTAL_DOPPLER", "DOPPLER_VENOSO_MMSS", "DOPPLER_ARTERIAL_MMSS", "TORAX", "QUADRIL_INFANTIL"].map((c) => [c, createInitialClinicalModelInput(c as any)]));
process.stdout.write(JSON.stringify({ source: "@laudousg/shared clinicalModels v1", sharedCommit, generatedAt: new Date().toISOString().slice(0, 10), normalAbdomenReport: (defaults.ABDOMEN_TOTAL_DOPPLER as any).abdomenReport, cases }, null, 2) + "\n");
}

void main();
