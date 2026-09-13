# Qualidade (LOD dos efeitos)

## Feito

- `Client/Quality.luau`: nivel Low/Medium/High lido do nivel grafico salvo do jogador
  (`Settings.Quality.SavedLevels` mapeia 1..10) ou, em Automatico, medido por FPS a cada
  `SampleSeconds` com histerese (`AutoFps`). `Quality.Set(level)` forca, `Quality.Set(nil)`
  volta ao automatico, `Quality.Changed` avisa (alpha.9).
- Cada nivel e uma tabela em `Settings.Quality.Levels` com: `TracerEvery`, `TracerTrail`,
  `TracerMaxDistance`, `TracerMaxLive`, `Casings`, `Impacts`, `MuzzleFlash`, `Shake`.
  Hoje so os tracers consomem; os outros entram na Fase 3.

## Regra combinada

Tudo que for efeito nasce bonito (nivel High) e ja pensado para cair de nivel: quem tem
grafico alto ve tudo, quem tem baixo ve menos ou nada, sozinho, sem o jogador configurar.

## Para depois

- Menu de opcoes no HUD para o jogador escolher o nivel a mao.
- Nivel por distancia dentro do mesmo grafico (LOD espacial), nao so por FPS.
- Sons tambem por nivel (quantidade de sons 3D simultaneos).
