# CBI — Monte Carlo “paper‑grade” (Versione 11)

Questo pacchetto è **standalone**: non dipende dalla versione demo e non contiene output pre‑caricati.
Gli output vengono creati **solo** quando lanci gli script.

## Struttura
- `S00_*.m`, `S10_*.m`, `S20_*.m` : **script di avvio** (entry points) — sono gli unici file che devi lanciare.
- `src/` : **funzioni** (logica riusabile: simulazioni, stime, export, plotting).
- `text/` : sezione LaTeX standalone (testo + inclusione automatica degli exhibits).
- `out/` : output (vuota di default). Dopo una run conterrà:
  - `out/exhibits/` (tables & figures usati in LaTeX, sempre sovrascritti)
  - `out/raw/` (oggetti “leggeri” per stage, opzionali, sempre sovrascritti)

## Quick start (ordine consigliato)

**Opzione A (consigliata, 1 comando):**
1. `RUN_ALL`  *(genera solo i main exhibits; sovrascrive `out/`)*

**Opzione B (run modulari):**
1. `WIPE_OUTPUTS`  *(opzionale ma consigliato prima di una nuova serie di run)*
2. `S00_smoke_test`  *(end-to-end sanity check)*
3. `S20_main_T_scaling_stage7` *(main paper-grade experiment: Stage 6 vs Stage 7)*
4. `S10_calibrate_bins`  *(opzionale: sensitivity su bins / sparsity)*
5. `S11_calibrate_ucb_c` *(opzionale: sensitivity su exploration constant c)*

**Nota sugli exhibits principali (v12):**
- `fig_paper_scaling.*` è una figura 2×2 (small multiples): righe = scenari (E, E2), colonne = (Regret = Policy−Oracle(ctx), Win rate = $\mathbb P(\text{Gap}<0)$). Le bande sono mean ± 2 MCSE.
- `tab_paper_scaling.tex` riporta Best(static), Policy, Gap, Oracle(ctx), Regret, Win rate e la sparsity dei conteggi context$\times$arm.

Per includere anche la tabella di sensitivity (bins $\times$ $c$) nel PDF, imposta
`\ShowCalibrationtrue` in `text/PaperMCMain.tex` e poi lancia `S10_...` / `S11_...`.

## LaTeX (PDF della sezione Monte Carlo)
Dopo che gli exhibits sono stati creati (in `out/exhibits/`), compila:
- `text/PaperMCMain.tex` (due passaggi di `pdflatex`)

Da MATLAB puoi usare:
```matlab
compile_paper_mc_tex()
```

## Nota sul Workspace (voluto)
Il pacchetto è “memory‑light”: gli oggetti grandi non rimangono in memoria; i risultati vanno in `out/`.
Se vuoi un riassunto nel Workspace, gli script salvano un struct `last_run` con i summary principali.
In più, a fine run stampano a schermo il path di `out/exhibits/` e la lista dei file generati.

## Path hygiene (evita collisioni)
Se MATLAB ha ancora in path vecchie versioni del pacchetto, possono apparire errori misteriosi.
`RUN_ALL` controlla automaticamente le collisioni sui file chiave e si ferma con un messaggio esplicito.
In caso di dubbi: `which dgp_library -all`.
