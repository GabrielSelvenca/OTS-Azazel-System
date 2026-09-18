# Tracados (tracers)

Anotacoes do Gabriel sobre o rastro da bala. Nada aqui e implementado fora da fase de efeitos
(Fase 3) ou do refinamento final, salvo o que esta marcado como feito.

## Feito

- Rastro (Trail) so liga um frame depois do Part sair do pool, ja no cano, e e limpo ao voltar. Antes
  o Trail desenhava um segmento do fim do tiro anterior ate o cano novo, parecendo uma bala subindo
  (0.2.0-alpha.2).
- Modo `Settings.Debug.ClientShots` (so Studio): linhas e bolas por tiro (camera, alvo, cabeca, cano,
  cada pellet) e print detalhado `[Azazel:Shot]` + `[Azazel:Tracer]`, com `ANOMALY` quando um pellet
  sai do cone.
- Rastro nasce no cano e nunca passa do ponto de impacto (alpha.7).
- Padrao grosso e brilhante, referencia Phantom Forces: 0.2 stud de largura, 5 de comprimento,
  amarelo vivo, opaco (alpha.8). Campos em `Effects.Tracer` por arma/classe: `Width`, `Length`,
  `Speed`, `Color`, `Every`, `Style`.
- Visual padrao centralizado em `Settings.Effects.Tracer` (cor, largura, comprimento, velocidade,
  fade do rastro, luz); arma/classe sobrescreve o que quiser (alpha.5). Cor padrao mais amarela.
- Luz na bala: `PointLight` sem sombra, `Settings.Effects.Tracer.Light`, ligada so a ate
  `TracerLightDistance` studs da camera por nivel de qualidade. Os "quadrados no chao" vem do `Lighting.Technology` em Voxel/Compatibility (grade de
  4 studs); com ShadowMap ou Future a luz fica lisa (alpha.5).
- Tiro de outro jogador nasce no cano da arma como o observador a ve (posicao local), nao no cano
  da copia do servidor, que fica atrasada. Primeiro frame ja mostra a barra saindo do cano; a 1200
  studs/s o passo de um frame e 20 studs, e o rastro (`Trail.Lifetime`) cobre o vao (alpha.6).
- Obedece o nivel de qualidade: densidade (`TracerEvery`), rastro ligado (`TracerTrail`),
  distancia da luz (`TracerLightDistance`), teto de pecas vivas (`TracerMaxLive`).
- Visivel de qualquer distancia (alpha.7): nao ha mais corte por distancia da camera; o jogador
  ve de longe de onde o tiro saiu e por onde passa. `MinPixelWidth` engrossa a barra o necessario
  para nunca ficar mais fina que N pixels na tela. Luz e o unico custo cortado por distancia.
- Estilo `Beam` (alpha.7): `Style = "Beam"` troca a Part Neon por um Beam plano virado para a
  camera, com `Beam.Texture` para textura de bala. `Rod` continua o padrao.
- Luz mais fraca e de cor fixa (`Light.Color`, brilho 0.5, alcance 8), independente da cor do
  tracado, para nao confundir com ele (alpha.7).
- Cor por arma ja e possivel (`Effects.Tracer.Color` em arma/classe); por decisao, todas iguais
  por enquanto.

## Para depois

- **Customizacao de cor do tracado** por jogador (skin/loja do jogo): API server tipo
  `Azazel.SetTracerColor(player, color)` replicada em `ShotFired`, com a luz sempre na cor fixa.
  O jogo que integra decide quem pode escolher o que.
- Textura de bala para o `Beam` (asset em `Assets/Effects`).
- Brilho no cano (muzzle flash) entra na Fase 3.
