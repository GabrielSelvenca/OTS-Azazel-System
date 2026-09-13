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
- Obedece o nivel de qualidade: densidade (`TracerEvery`), rastro ligado (`TracerTrail`),
  distancia maxima da camera (`TracerMaxDistance`), teto de pecas vivas (`TracerMaxLive`).

## Para depois

- Estilo `Beam` (hoje so `Trail` existe de fato); textura de bala para o Beam.
- Cor por arma/municao (tracante vs normal), talvez por time.
- Brilho/glow real (Highlight ou ParticleEmitter no cano) quando a fase de efeitos entrar.
- LOD por distancia dentro do mesmo nivel (fino de longe, grosso de perto).
