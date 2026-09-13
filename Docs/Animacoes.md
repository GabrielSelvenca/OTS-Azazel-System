# Animacoes e cadencia

Anotacoes de pedidos fora da fase atual sobre animacao e o que ela controla. A Fase 4 do
`PLANO.md` e onde isso entra.

## Feito

- Um portao so no client, `WeaponController.CanFire()`: pronto, com bala, vivo e fora do intervalo. Clique
  indisponivel e descartado; segurar o gatilho durante recarga ou troca nao retoma o tiro. O servidor
  ja descartava tudo fora das regras dele e continua (0.2.0-alpha.4).
- Clique durante o intervalo entre tiros e ignorado (nao fica em fila para disparar quando o
  intervalo acaba). Vale para Semi e Burst (0.2.0-alpha.3).

## Para depois (Fase 4)

- **Cadencia guiada pela animacao** (pedido em 2026-09-13). Arma com atraso entre tiros (sniper
  de ferrolho, shotgun de bomba) tem uma animacao no meio; o proximo tiro so libera quando o slot
  `Fire` termina, nao por um timer solto. Reload cancela a animacao de `Fire` e o intervalo, e
  comeca a recarga na hora. Qualquer outro clique durante `Fire` e ignorado.
- Como fazer sem abrir brecha: o servidor nao pode confiar em "a animacao acabou" vindo do client,
  entao o tempo do config (`ShotInterval`, `Reload.Time`, `EquipTime`) continua sendo a regra no
  servidor. O client usa a animacao como gatilho visual e o `AnimationSet` ajusta a velocidade do
  clip (`AdjustSpeed`) para o comprimento da KeyframeSequence bater com o tempo do config. Assim
  o fim da animacao e o fim do intervalo sao o mesmo instante para o jogador.
- Alternativa se o Gabriel preferir animar sem se preocupar com tempo: comando de Studio que le o
  comprimento de cada KeyframeSequence e grava `ShotInterval`/`Reload.Time` no config da arma.
